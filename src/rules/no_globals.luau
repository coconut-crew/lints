-- ai marker
-- Skip implicit self bindings, which have no source name token.
-- Offer const or local fixes for simple declarations, excluding shadows and globals needing localization.
const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const syntax_types = require(`@std/syntax/types`)
const visitor = require(`@std/syntax/visitor`)

const name = `no_global_declarations`
const severity: lint_types.severity = `error`

type Scope = {
	index: number,
	last_index: number,
	depth: number,
	ancestors: { Scope },
	entry: syntax.Span,
}

type Reference = {
	expression: syntax.CstExprGlobal,
	scope: Scope,
}

type Global = {
	first: Reference,
	min_scope: Scope,
	max_scope: Scope,
}

const function common_scope(first: Scope, last: Scope): Scope
	if first.last_index >= last.index then
		return first
	end
	local cursor = first
	for level = #first.ancestors, 1, -1 do
		const ancestor = cursor.ancestors[level]
		if ancestor ~= nil and ancestor.last_index < last.index then
			cursor = ancestor
		end
	end
	return (assert)(cursor.ancestors[1])
end

const function insertion_location(first: Reference, scope: Scope): syntax.Span
	local cursor = first.scope
	for level = #cursor.ancestors, 1, -1 do
		const ancestor = cursor.ancestors[level]
		if ancestor ~= nil and ancestor.depth > scope.depth then
			cursor = ancestor
		end
	end
	return cursor.entry
end

const function references_global(expression: syntax.CstExpr, global_name: string): boolean
	local found = false
	const walker = visitor.create()
	walker.visitExprGlobal = function(reference: syntax.CstExprGlobal): boolean
		if reference.name.text == global_name then
			found = true
		end
		return true
	end
	visitor.visitExpression(expression, walker)
	return found
end

const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const globals: { [string]: Global } = {}
	const ordered_globals: { Global } = {}
	const assign_counts: { [string]: number } = {}
	const declarations: { [syntax.CstExprGlobal]: syntax.Span } = {}
	const locals: { [string]: syntax.CstLocal } = {}
	const scopes: { Scope } = {}
	local scope_count = 0
	local statement_location = cst.location
	const walker = visitor.create()

	const function push_scope(): Scope
		const parent = scopes[#scopes]
		const ancestors: { Scope } = {}
		if parent ~= nil then
			ancestors[1] = parent
			local level = 1
			local ancestor = parent.ancestors[level]
			while ancestor ~= nil do
				ancestors[level + 1] = ancestor
				level += 1
				ancestor = ancestor.ancestors[level]
			end
		end
		scope_count += 1
		const scope: Scope = {
			index = scope_count,
			last_index = scope_count,
			depth = #scopes,
			ancestors = ancestors,
			entry = statement_location,
		}
		table.insert(scopes, scope)
		return scope
	end

	const function visit_statements(block: syntax.CstStatBlock): ()
		for _, statement in block.statements do
			statement_location = statement.location
			visitor.visitStatement(statement, walker)
		end
	end

	walker.visitStatBlock = function(block: syntax.CstStatBlock): boolean
		const saved_location = statement_location

		const scope = push_scope()

		visit_statements(block)

		scope.last_index = scope_count
		table.remove(scopes)

		statement_location = saved_location

		return false
	end

	walker.visitStatRepeat = function(statement: syntax.CstStatRepeat): boolean
		const saved_location = statement_location

		const scope = push_scope()

		visit_statements(statement.body)
		statement_location = statement.untilKeyword.location
		visitor.visitExpression(statement.condition, walker)

		scope.last_index = scope_count
		table.remove(scopes)

		statement_location = saved_location

		return false
	end

	walker.visitStatTypeFunction = function(
		_statement: syntax_types.CstStatTypeFunction
	): boolean
		-- Type functions execute in a separate environment from runtime globals.
		return false
	end

	walker.visitLocal = function(binding: syntax.CstLocal): boolean
		if binding.name == nil then
			return false
		end
		const previous = locals[binding.name.text]
		if
			previous == nil
			or binding.name.location.beginLine < previous.name.location.beginLine
		then
			locals[binding.name.text] = binding
		end
		return true
	end

	const function mark_assignment(target: syntax.CstExprGlobal): ()
		const target_name = target.name.text
		const old = assign_counts[target_name]
		assign_counts[target_name] = old and old + 1 or 1
	end
	const function try_mark_assignment(target: syntax.CstExpr): ()
		if target.tag == `global` then
			mark_assignment(target)
		end
	end

	walker.visitStatAssign = function(statement: syntax.CstStatAssign): boolean
		for _, target in statement.variables do
			try_mark_assignment(target)
		end
		const target = statement.variables[1]
		const value = statement.values[1]
		if
			#statement.variables == 1
			and #statement.values == 1
			and target ~= nil
			and target.tag == `global`
			and value ~= nil
			and not references_global(value, target.name.text)
		then
			-- A const binding is not visible in its initializer, including nested functions.
			declarations[target] = statement.location
		end
		return true
	end
	walker.visitStatCompoundAssign = function(
		statement: syntax.CstStatCompoundAssign
	): boolean
		try_mark_assignment(statement.variable)
		return true
	end
	walker.visitStatFunction = function(statement: syntax.CstStatFunction): boolean
		try_mark_assignment(statement.name)
		if statement.name.tag == `global` then
			declarations[statement.name] = statement.location
		end
		return true
	end

	walker.visitExprGlobal = function(expression: syntax.CstExprGlobal): boolean
		const scope = (assert)(scopes[#scopes])
		const reference: Reference = { expression = expression, scope = scope }
		const info = globals[expression.name.text]

		if info == nil then
			const created: Global = {
				first = reference,
				min_scope = scope,
				max_scope = scope,
			}
			globals[expression.name.text] = created
			table.insert(ordered_globals, created)
			return true
		end

		if scope.index < info.min_scope.index then
			info.min_scope = scope
		end
		if scope.index > info.max_scope.index then
			info.max_scope = scope
		end

		return true
	end

	visitor.visitBlock(cst, walker)

	const violations: { lint_types.LintViolation } = {}
	for _, info in ordered_globals do
		const assign_count = assign_counts[info.first.expression.name.text]
		const binding = locals[info.first.expression.name.text]
		if not assign_count and binding == nil then
			continue
		end

		const is_const = assign_count == 1

		const scope = common_scope(info.min_scope, info.max_scope)
		const location = info.first.expression.name.location
		const declaration = declarations[info.first.expression]
		const can_fix = binding == nil
			and scope == info.first.scope
			and declaration ~= nil
		local message = if is_const
			then `this global can safely get a const declaration here`
			else `this global can safely get a local declaration here`

		if binding ~= nil then
			message =
				`this global shadows a local with the same name at line {binding.name.location.beginLine}`
		elseif scope ~= info.first.scope then
			const declaration_location = insertion_location(info.first, scope)
			message = if is_const
				then `localize this global at or above line {declaration_location.beginLine} as a const variable`
				else `localize this global at or above line {declaration_location.beginLine}`
		end

		table.insert(violations, {
			lintname = name,
			location = location,
			message = message,
			severity = severity,
			sourcepath = sourcepath,
			suggestedfix = if can_fix and declaration ~= nil
				then {
					location = syntax.span.create({
						beginLine = declaration.beginLine,
						beginColumn = declaration.beginColumn,
						endLine = declaration.beginLine,
						endColumn = declaration.beginColumn,
					}),
					fix = if is_const then `const ` else `local `,
				}
				else nil,
		})
	end
	return violations
end

const rule: lint_types.LintRule = { name = name, lint = lint }
return table.freeze(rule)
