const global_analysis = require("@utils/global_analysis")
const lint_types = require(`@lint`)
const pathlib = require("@std/path")
const scope_analysis = require("@utils/scope_analysis")
const syntax = require("@std/syntax")
const visitor = require("@std/syntax/visitor")

const lint_name = `no_global_values`
const lint_severity: lint_types.severity = "error"

const function find_shared_scope(
	min: scope_analysis.SyntaxScope,
	max: scope_analysis.SyntaxScope
): scope_analysis.SyntaxScope
	const min_id = min.start_id

	local shared_scope = max
	while shared_scope and shared_scope.start_id > min_id do
		shared_scope = shared_scope.parent
	end
	if not shared_scope then
		error(`could not find a shared parent between \z
			scope {min_id} \z
			and {max.start_id}; \z
			all scopes should share a root, so this should never happen`)
	end

	return shared_scope
end

const function find_anchor(
	scope: scope_analysis.SyntaxScope,
	target: scope_analysis.SyntaxScope
): scope_analysis.SyntaxScope
	-- these initialize as the same value because it's possible that scope == target
	local child_scope, parent_scope = scope, scope
	while parent_scope and parent_scope ~= target do
		child_scope = parent_scope
		parent_scope = parent_scope.parent
	end

	return child_scope
end

const function collect_locals(cst: syntax.CstStatBlock): { [string]: syntax.Span }
	const locals: { [string]: syntax.Span } = {}
	const walker = visitor.create()

	function walker.visitStatTypeFunction()
		return false
	end

	function walker.visitLocal(node)
		const name = node.name
		-- bad lute typedef
		if name == nil then
			return true
		end

		const existing = locals[name.text]
		if existing == nil or name.location.beginLine < existing.beginLine then
			locals[name.text] = name.location
		end
		return true
	end

	visitor.visitBlock(cst, walker)

	return locals
end

const function no_global_values(
	cst: syntax.CstStatBlock,
	sourcepath: pathlib.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations = {}

	const scope_data = scope_analysis.analyze_block(cst)
	const global_data = global_analysis.analyze_block(cst, scope_data)

	const locals = collect_locals(cst)

	for _, global in global_data.ordered_globals do
		-- we don't want to flag read-only globals like 'print'
		if global.assign_count == 0 then
			continue
		end

		const shared_scope = find_shared_scope(global.min_scope, global.max_scope)
		-- we can't replace this variable with min scope because the
		-- first ref's scope might be in a deeper (and therefore higher) scope
		const first_ref_scope = assert(scope_data.expr_scopes[global.first_ref])

		const target = if global.forward_declared
			then shared_scope.stable_superscope
			else shared_scope
		const anchor = find_anchor(first_ref_scope, target)

		const kind = if global.assign_count == 1
				and not global.forward_declared
				and anchor == target
			then `const`
			else `local`

		local message = `this global`

		const shadowed_local = locals[global.name]
		if shadowed_local then
			message ..= ` might be trying to access a local first used on line {shadowed_local.beginLine}. if not, {global.name}`
		end

		message ..= if anchor == target
			then ` should get a {kind} declaration here`
			else ` should get a {kind} declaration near line {anchor.begin_line}`

		table.insert(violations, {
			lintname = lint_name,
			location = global.first_ref.location,
			message = message,
			severity = lint_severity,
			sourcepath = sourcepath,
		})
	end

	return violations
end

const rule: lint_types.LintRule = {
	name = lint_name,
	lint = no_global_values,
}

return table.freeze(rule)
