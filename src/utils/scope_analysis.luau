const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

--[=[
note: if implementing variable analysis connecting to scopes,
beware these scoping cases:

```luau
-- safe, body vars are accessible from the condition
repeat local hi = 123 until hi

repeat
    if cond then continue end
    local hi = 123

-- compile error because 'hi' may be undefined
until hi

-- 'i' is part of the body's scope but visited before it
for i = 1, 2 do
end

-- recursion is allowed in `function ...()` declarations
local function foo()
    foo()
end

-- but not when declared like this:
local foo = function()
    -- attempt to call nil value
    foo()
end

local a
type function foo()
	-- 'a' is not in scope as a variable here
end
```
]=]
export type SyntaxScope = {
	read parent: SyntaxScope?,
	read begin_line: number,
	read begin_column: number,

	read depth: number,
	--- the id representing this scope
	read start_id: number,
	--- the id representing the furthest descendant of this scope
	final_id: number,
}

export type ScopeAnalysis = {
	read scope_map: { read [syntax.CstStatBlock]: SyntaxScope? },
	read ordered_scopes: { read [number]: SyntaxScope },
	read expr_scopes: { read [syntax.CstExpr]: SyntaxScope? },
}

const walker = visitor.create()
const function create_state(block: syntax.CstStat)
	return {
		depth = 0,
		scope_id = 0,
		ordered_scopes = {} :: { SyntaxScope },
		scope_map = {} :: { [syntax.CstStatBlock]: SyntaxScope? },
		-- this determines the begin_line and begin_column of a scope
		statement_location = block.location,
		parent_scope = nil :: SyntaxScope?,
		expr_scopes = {} :: { [syntax.CstExpr]: SyntaxScope? },
	}
end
local state: typeof(create_state(...))

function walker.visitExpr(node)
	state.expr_scopes[node] = state.parent_scope

	return true
end

const function visit_statements(block: syntax.CstStatBlock): ()
	for _, statement in block.statements do
		state.statement_location = statement.location
		visitor.visitStatement(statement, walker)
	end
end

const function visit_scope(
	block: syntax.CstStatBlock,
	repeat_stat: syntax.CstStatRepeat | false
): ()
	const this_id = state.scope_id + 1
	state.scope_id = this_id

	const this_depth = state.depth + 1
	state.depth = this_depth

	-- we need to reset this after visiting inner statements so
	-- statements inside this scope don't bleed into sibling scopes
	const beginning_statement_location = state.statement_location

	const parent_scope = state.parent_scope
	const scope_object: SyntaxScope = {
		parent = parent_scope,
		begin_line = beginning_statement_location.beginLine,
		begin_column = beginning_statement_location.beginColumn,

		depth = this_depth,
		start_id = this_id,
		final_id = this_id,
	}

	state.ordered_scopes[this_id] = scope_object
	state.scope_map[block] = scope_object

	state.parent_scope = scope_object

	visit_statements(block)

	-- although a repeat condition is not a sibling lexically, it's
	-- convenient for them to share an initial location with the body.
	-- importantly, scopes inside the repeat condition are still
	-- children, so they can access variables inside the main body,
	-- but their initial location will be **outside** the span of
	-- their parent.
	state.statement_location = beginning_statement_location
	if repeat_stat then
		visitor.visitToken(repeat_stat.untilKeyword, walker)
		visitor.visitExpression(repeat_stat.condition, walker)
	end

	scope_object.final_id = state.scope_id
	state.parent_scope, state.depth = parent_scope, this_depth - 1
end

function walker.visitStatBlock(node)
	visit_scope(node, false)
	return false
end

function walker.visitStatRepeat(node)
	visitor.visitToken(node.repeatKeyword, walker)
	visit_scope(node.body, node)
	return false
end

const scope_analysis = {}

function scope_analysis.analyze_block(block: syntax.CstStatBlock): ScopeAnalysis
	state = create_state(block)

	visitor.visitBlock(block, walker)

	return {
		ordered_scopes = state.ordered_scopes,
		scope_map = state.scope_map,
		expr_scopes = state.expr_scopes,
	}
end

return table.freeze(scope_analysis)
