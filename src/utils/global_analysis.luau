const scope_analysis = require("@utils/scope_analysis")
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

export type Global = {
	read name: string,
	read first_ref: syntax.CstExprGlobal,

	min_scope: scope_analysis.SyntaxScope,
	max_scope: scope_analysis.SyntaxScope,

	assign_count: number,
	--- whether the variable's first reference is different from its
	--- first declaration
	forward_declared: boolean,
}

export type GlobalAnalysis = {
	read globals: { [string]: Global? },
	read ordered_globals: { Global },
}

const walker = visitor.create()
const function create_state(scope_data: scope_analysis.ScopeAnalysis)
	return {
		expr_scopes = scope_data.expr_scopes,
		globals = {} :: { [string]: Global? },
		ordered_globals = {} :: { Global },
	}
end
local state: typeof(create_state(...))

-- we don't want to do global analysis for udtfs
function walker.visitStatTypeFunction()
	return false
end

const function reference_global_data(node: syntax.CstExprGlobal): Global
	const scope = assert(state.expr_scopes[node])

	const globals, global_name = state.globals, node.name.text

	const existing = globals[global_name]
	if existing then
		if scope.start_id < existing.min_scope.start_id then
			existing.min_scope = scope
		end
		if scope.final_id > existing.max_scope.final_id then
			existing.max_scope = scope
		end

		return existing
	end

	const created: Global = {
		name = global_name,
		first_ref = node,
		assign_count = 0,
		min_scope = scope,
		max_scope = scope,
		forward_declared = false,
	}
	globals[global_name] = created
	table.insert(state.ordered_globals, created)

	return created
end

function walker.visitExprGlobal(node)
	-- technically this could be called earlier on the same node while
	-- registering assignments, but the reference fn is idempotent
	reference_global_data(node)

	return true
end

const function process_assignment(node: syntax.CstExpr, compound_assignment: boolean): ()
	if node.tag ~= "global" then
		return
	end

	const global = reference_global_data(node)

	const assign_count = global.assign_count + 1
	global.assign_count = assign_count

	if assign_count == 1 and (not compound_assignment or global.first_ref ~= node) then
		global.forward_declared = true
	end
end

function walker.visitStatAssign(node)
	for _, variable in node.variables do
		process_assignment(variable, false)
	end

	return true
end

function walker.visitStatCompoundAssign(node)
	process_assignment(node.variable, true)

	return true
end

function walker.visitStatFunction(node)
	process_assignment(node.name, false)

	return true
end

const global_analysis = {}

function global_analysis.analyze_block(
	block: syntax.CstStatBlock,
	scope_data: scope_analysis.ScopeAnalysis
): GlobalAnalysis
	state = create_state(scope_data)

	visitor.visitBlock(block, walker)

	return {
		globals = state.globals,
		ordered_globals = state.ordered_globals,
	}
end

return table.freeze(global_analysis)
