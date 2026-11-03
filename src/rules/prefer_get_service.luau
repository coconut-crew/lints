-- ai marker
-- Skip implicit self bindings, which have no source name token.
-- Handle workspace and direct game indexing together, reusing safe existing service bindings.
-- Withhold fixes for conflicting names, writes, and references before existing declarations.

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const service_names = require("../data/service_names")
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `prefer_get_service`
const severity: lint_types.severity = `warning`

type Reference = { service: string, location: syntax.Span }
type ServiceBinding = { binding: syntax.CstLocal, location: syntax.Span }

const function unwrap(expression: syntax.CstExpr): syntax.CstExpr
	local current = expression
	while current.tag == `group` or current.tag == `cast` do
		current = if current.tag == `group` then current.expression else current.operand
	end
	return current
end

const function indexed_service(expression: syntax.CstExpr): string?
	local member: string
	local base: syntax.CstExpr
	if expression.tag == `indexname` and expression.accessor.text == `.` then
		member = expression.index.text
		base = expression.expression
	elseif expression.tag == `index` and expression.index.tag == `string` then
		member = expression.index.value.text
		base = expression.expression
	else
		return nil
	end
	const receiver = unwrap(base)
	if receiver.tag ~= `global` or receiver.name.text ~= `game` then
		return nil
	end
	-- Roblox also exposes the legacy lowercase workspace property.
	if member == `workspace` then
		return `Workspace`
	end
	return if service_names[member] then member else nil
end

const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const references: { Reference } = {}
	const conflicts: { [string]: boolean } = {}
	const service_bindings: { [string]: ServiceBinding } = {}
	for _, statement in cst.statements do
		if statement.tag ~= `local` and statement.tag ~= `const` then
			continue
		end
		const binding = statement.variables[1]
		const value = statement.values[1]
		if #statement.variables ~= 1 or binding == nil or value == nil then
			continue
		end
		const call = unwrap(value)
		if call.tag ~= `call` or #call.arguments ~= 1 then
			continue
		end
		const method = call.func
		const argument = call.arguments[1]
		if method.tag ~= `indexname` then
			continue
		end
		const receiver = unwrap(method.expression)
		if
			method.accessor.text == `:`
			and method.index.text == `GetService`
			and receiver.tag == `global`
			and receiver.name.text == `game`
			and argument ~= nil
			and argument.tag == `string`
			and service_names[argument.value.text]
			and binding.name.text == argument.value.text
		then
			service_bindings[argument.value.text] =
				{ binding = binding, location = statement.location }
		end
	end
	local game_assigned = false
	const walker = visitor.create()
	walker.visitStatTypeFunction = function(): boolean
		return false
	end
	walker.visitLocal = function(binding: syntax.CstLocal): boolean
		if binding.name == nil then
			return false
		end
		const existing = service_bindings[binding.name.text]
		if existing == nil or existing.binding ~= binding then
			conflicts[binding.name.text] = true
		end
		return true
	end
	walker.visitExprGlobal = function(expression: syntax.CstExprGlobal): boolean
		conflicts[expression.name.text] = true
		if expression.name.text == `workspace` then
			table.insert(
				references,
				{ service = `Workspace`, location = expression.location }
			)
		end
		return true
	end
	walker.visitTypeReference = function(reference: syntax.CstTypeReference): boolean
		if reference.prefix ~= nil then
			conflicts[reference.prefix.text] = true
		end
		return true
	end
	const function record_reference(expression: syntax.CstExpr): boolean
		const service = indexed_service(expression)
		if service ~= nil then
			table.insert(
				references,
				{ service = service, location = expression.location }
			)
		end
		return true
	end
	walker.visitExprIndexName = record_reference
	walker.visitExprIndexExpr = record_reference

	const function check_write(expression: syntax.CstExpr): ()
		const target = unwrap(expression)
		if target.tag == `global` and target.name.text == `game` then
			game_assigned = true
		elseif target.tag == `global` and target.name.text == `workspace` then
			conflicts.Workspace = true
		elseif target.tag == `local` then
			const binding = target["local"]
			if binding.name ~= nil then
				const existing = service_bindings[binding.name.text]
				if existing ~= nil and existing.binding == binding then
					conflicts[binding.name.text] = true
				end
			end
		end
		const service = indexed_service(target)
		if service ~= nil then
			-- Replacing a service assignment would assign to the new constant instead.
			conflicts[service] = true
		end
	end
	walker.visitStatAssign = function(statement: syntax.CstStatAssign): boolean
		for _, target in statement.variables do
			check_write(target)
		end
		return true
	end
	walker.visitStatCompoundAssign = function(
		statement: syntax.CstStatCompoundAssign
	): boolean
		check_write(statement.variable)
		return true
	end
	walker.visitStatFunction = function(statement: syntax.CstStatFunction): boolean
		check_write(statement.name)
		return true
	end
	visitor.visitBlock(cst, walker)

	const violations: { lint_types.LintViolation } = {}
	const declarations: { string } = {}
	const declared: { [string]: boolean } = {}
	for _, reference in references do
		const service = reference.service
		const declaration = `const {service} = game:GetService("{service}")`
		const existing = service_bindings[service]
		const after_declaration = existing == nil
			or reference.location.beginLine > existing.location.endLine
			or (
				reference.location.beginLine == existing.location.endLine
				and reference.location.beginColumn >= existing.location.endColumn
			)
		const can_fix = not conflicts[service] and not game_assigned and after_declaration
		if can_fix and existing == nil and not declared[service] then
			declared[service] = true
			table.insert(declarations, declaration)
		end
		table.insert(violations, {
			lintname = name,
			location = reference.location,
			message = if existing ~= nil
				then `Use '{service}' instead of direct service access.`
				else `Use '{service}' instead of direct service access; declare '{declaration}' at the top of the file.`,
			severity = severity,
			sourcepath = sourcepath,
			suggestedfix = if can_fix then { fix = service } else nil,
		})
	end

	const first_statement = cst.statements[1]
	if #declarations > 0 and first_statement ~= nil then
		const start = first_statement.location
		const insertion = table.concat(declarations, `\n`) .. `\n`
		-- Combine declarations into one insertion and avoid overlapping a replacement at the same position.
		for _, violation in violations do
			const fix = violation.suggestedfix
			if
				fix ~= nil
				and violation.location.beginLine == start.beginLine
				and violation.location.beginColumn == start.beginColumn
			then
				violation.suggestedfix = { fix = insertion .. fix.fix }
				return violations
			end
		end
		table.insert(violations, {
			lintname = name,
			location = syntax.span.create({
				beginLine = start.beginLine,
				beginColumn = start.beginColumn,
				endLine = start.beginLine,
				endColumn = start.beginColumn,
			}),
			message = `Declare services at the top of the file using game:GetService().`,
			severity = severity,
			sourcepath = sourcepath,
			suggestedfix = { fix = insertion },
		})
	end
	return violations
end

const rule: lint_types.LintRule = { name = name, lint = lint }
return table.freeze(rule)
