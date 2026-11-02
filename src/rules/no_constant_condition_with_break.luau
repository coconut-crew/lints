-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `no_constant_condition_with_break`
const message = `Unexpected constant condition.`
const severity: lint_types.severity = `warning`

const truthy_binary_operators: { [string]: true? } = {
	[`%`] = true,
	[`*`] = true,
	[`+`] = true,
	[`-`] = true,
	[`..`] = true,
	[`/`] = true,
	[`//`] = true,
	[`^`] = true,
}

type EvaluationFrame = {
	read expanded: boolean,
	read expression: syntax.CstExpr,
}

type TruthinessByExpression = {
	[syntax.CstExpr]: boolean?,
}

--[=[
	ai generated implementation
]=]
const function parse_loop_exit_calls(context: lint_types.RuleContext): { [string]: true? }
	const calls: { [string]: true? } = {}
	local raw_calls = context.options.loop_exit_calls
	if raw_calls == nil then
		raw_calls = context.options.loopExitCalls
	end
	if type(raw_calls) ~= `table` then
		return calls
	end

	for _, value in raw_calls :: { unknown } do
		if type(value) == `string` and #value > 0 then
			calls[value] = true
		end
	end
	return calls
end

--[=[
	ai generated implementation
]=]
const function expression_path(expression: syntax.CstExpr): string?
	local suffix = ``
	local cursor = expression

	while true do
		if cursor.tag == `group` then
			cursor = cursor.expression
		elseif cursor.tag == `cast` then
			cursor = cursor.operand
		elseif cursor.tag == `instantiate` then
			cursor = cursor.expr
		elseif cursor.tag == `indexname` then
			suffix = `.{cursor.index.text}{suffix}`
			cursor = cursor.expression
		elseif cursor.tag == `local` then
			return cursor.token.text .. suffix
		elseif cursor.tag == `global` then
			return cursor.name.text .. suffix
		else
			return nil
		end
	end
end

--[=[
	ai generated implementation
]=]
const function expression_contains_configured_exit(
	expression: syntax.CstExpr,
	exit_calls: {
		[string]: true?,
	}
): boolean
	if next(exit_calls) == nil then
		return false
	end

	local found = false
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunction = function(
		_function_expression: syntax.CstExprFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprCall = function(call: syntax.CstExprCall): boolean
		const call_path = expression_path(call.func)
		if call_path ~= nil and exit_calls[call_path] == true then
			found = true
			return false
		end
		return true
	end

	visitor.visitExpression(expression, walker)
	return found
end

--[=[
	ai generated implementation
]=]
const function block_contains_configured_exit(
	block: syntax.CstStatBlock,
	exit_calls: { [string]: true? }
): boolean
	if next(exit_calls) == nil then
		return false
	end

	local found = false
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatFunction = function(_statement: syntax.CstStatFunction): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		_statement: syntax.CstStatLocalFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatTypeFunction = function(
		_statement: syntax.CstStatTypeFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunction = function(
		_function_expression: syntax.CstExprFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprCall = function(call: syntax.CstExprCall): boolean
		const call_path = expression_path(call.func)
		if call_path ~= nil and exit_calls[call_path] == true then
			found = true
			return false
		end
		return true
	end

	visitor.visitBlock(block, walker)
	return found
end

--[=[
	ai generated implementation
]=]
const function block_contains_return(block: syntax.CstStatBlock): boolean
	local found = false
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatFunction = function(_statement: syntax.CstStatFunction): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		_statement: syntax.CstStatLocalFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatTypeFunction = function(
		_statement: syntax.CstStatTypeFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunction = function(
		_function_expression: syntax.CstExprFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatReturn = function(_return_statement: syntax.CstStatReturn): boolean
		found = true
		return false
	end

	visitor.visitBlock(block, walker)
	return found
end

--[=[
	ai generated implementation
]=]
const function block_contains_break_for_current_loop(block: syntax.CstStatBlock): boolean
	local found = false
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatFunction = function(_statement: syntax.CstStatFunction): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		_statement: syntax.CstStatLocalFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatTypeFunction = function(
		_statement: syntax.CstStatTypeFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunction = function(
		_function_expression: syntax.CstExprFunction
	): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatWhile = function(_nested_loop: syntax.CstStatWhile): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatRepeat = function(_nested_loop: syntax.CstStatRepeat): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatFor = function(_nested_loop: syntax.CstStatFor): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatForIn = function(_nested_loop: syntax.CstStatForIn): boolean
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatBreak = function(_break_statement: syntax.CstStatBreak): boolean
		found = true
		return false
	end

	visitor.visitBlock(block, walker)
	return found
end

--[=[
	ai generated implementation
]=]
const function loop_contains_exit(
	condition: syntax.CstExpr,
	body: syntax.CstStatBlock,
	exit_calls: { [string]: true? }
): boolean
	return expression_contains_configured_exit(condition, exit_calls)
		or block_contains_configured_exit(body, exit_calls)
		or block_contains_return(body)
		or block_contains_break_for_current_loop(body)
end

--[=[
	ai generated implementation
]=]
const function add_evaluation_children(
	expression: syntax.CstExpr,
	stack: { EvaluationFrame }
): ()
	if expression.tag == `group` then
		table.insert(stack, {
			expanded = false,
			expression = expression.expression,
		})
	elseif expression.tag == `cast` then
		table.insert(stack, {
			expanded = false,
			expression = expression.operand,
		})
	elseif expression.tag == `unary` then
		table.insert(stack, {
			expanded = false,
			expression = expression.operand,
		})
	elseif expression.tag == `binary` then
		table.insert(stack, {
			expanded = false,
			expression = expression.lhsOperand,
		})
		table.insert(stack, {
			expanded = false,
			expression = expression.rhsOperand,
		})
	elseif expression.tag == `conditional` then
		table.insert(stack, {
			expanded = false,
			expression = expression.condition,
		})
		table.insert(stack, {
			expanded = false,
			expression = expression.thenExpr,
		})
		for _, elseif_clause in expression.elseifs do
			table.insert(stack, {
				expanded = false,
				expression = elseif_clause.condition,
			})
			table.insert(stack, {
				expanded = false,
				expression = elseif_clause.thenExpr,
			})
		end
		table.insert(stack, {
			expanded = false,
			expression = expression.elseExpr,
		})
	end
end

--[=[
	ai generated implementation
]=]
const function conditional_truthiness(
	expression: syntax.CstExprIfElse,
	truthiness: TruthinessByExpression
): boolean?
	const conditions: { syntax.CstExpr } = { expression.condition }
	const branches: { syntax.CstExpr } = { expression.thenExpr }
	for _, elseif_clause in expression.elseifs do
		table.insert(conditions, elseif_clause.condition)
		table.insert(branches, elseif_clause.thenExpr)
	end

	local expected = false
	local has_expected = false
	local reachable = true
	for index, condition in conditions do
		if not reachable then
			break
		end

		const condition_value = truthiness[condition]
		if condition_value ~= false then
			const branch_value = truthiness[branches[index]]
			if branch_value == nil then
				return nil
			elseif not has_expected then
				expected = branch_value
				has_expected = true
			elseif expected ~= branch_value then
				return nil
			end
		end

		if condition_value == true then
			reachable = false
		end
	end

	if reachable then
		const else_value = truthiness[expression.elseExpr]
		if else_value == nil then
			return nil
		elseif not has_expected then
			expected = else_value
			has_expected = true
		elseif expected ~= else_value then
			return nil
		end
	end

	return if has_expected then expected else nil
end

--[=[
	ai generated implementation
]=]
const function constant_truthiness(root: syntax.CstExpr): boolean?
	const truthiness: TruthinessByExpression = {}
	const stack: { EvaluationFrame } = {
		{
			expanded = false,
			expression = root,
		},
	}

	while #stack > 0 do
		const frame = table.remove(stack)
		if frame == nil then
			continue
		end
		const expression = frame.expression

		if not frame.expanded then
			table.insert(stack, {
				expanded = true,
				expression = expression,
			})
			add_evaluation_children(expression, stack)
			continue
		end

		local value: boolean? = nil
		if expression.tag == `nil` then
			value = false
		elseif expression.tag == `boolean` then
			value = expression.value
		elseif
			expression.tag == `number`
			or expression.tag == `integer`
			or expression.tag == `string`
			or expression.tag == `interpolatedstring`
			or expression.tag == `table`
			or expression.tag == `function`
		then
			value = true
		elseif expression.tag == `group` then
			value = truthiness[expression.expression]
		elseif expression.tag == `cast` then
			value = truthiness[expression.operand]
		elseif expression.tag == `unary` then
			if expression.operator.text == `not` then
				const operand = truthiness[expression.operand]
				if operand ~= nil then
					value = not operand
				end
			elseif expression.operator.text == `-` or expression.operator.text == `#` then
				value = true
			end
		elseif expression.tag == `binary` then
			const lhs = truthiness[expression.lhsOperand]
			const rhs = truthiness[expression.rhsOperand]
			if expression.operator.text == `and` then
				if lhs == false or rhs == false then
					value = false
				elseif lhs == true then
					value = rhs
				end
			elseif expression.operator.text == `or` then
				if lhs == true or rhs == true then
					value = true
				elseif lhs == false then
					value = rhs
				end
			elseif truthy_binary_operators[expression.operator.text] then
				value = true
			end
		elseif expression.tag == `conditional` then
			value = conditional_truthiness(expression, truthiness)
		end

		if value ~= nil then
			truthiness[expression] = value
		end
	end

	return truthiness[root]
end

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations: { lint_types.LintViolation } = {}
	const exit_calls = parse_loop_exit_calls(context)

	--[=[
		ai generated implementation
	]=]
	const function report(condition: syntax.CstExpr): ()
		table.insert(violations, {
			lintname = name,
			location = condition.location,
			message = message,
			severity = severity,
			sourcepath = sourcepath,
		})
	end

	--[=[
		ai generated implementation
	]=]
	const function report_plain_condition(condition: syntax.CstExpr): ()
		if constant_truthiness(condition) ~= nil then
			report(condition)
		end
	end

	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatIf = function(statement: syntax.CstStatIf): boolean
		report_plain_condition(statement.condition)
		for _, elseif_clause in statement.elseifs do
			report_plain_condition(elseif_clause.condition)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprIfElse = function(expression: syntax.CstExprIfElse): boolean
		report_plain_condition(expression.condition)
		for _, elseif_clause in expression.elseifs do
			report_plain_condition(elseif_clause.condition)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatWhile = function(statement: syntax.CstStatWhile): boolean
		const value = constant_truthiness(statement.condition)
		if value == false then
			report(statement.condition)
		elseif
			value == true
			and not loop_contains_exit(statement.condition, statement.body, exit_calls)
		then
			report(statement.condition)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatRepeat = function(statement: syntax.CstStatRepeat): boolean
		const value = constant_truthiness(statement.condition)
		if value == true then
			report(statement.condition)
		elseif
			value == false
			and not loop_contains_exit(statement.condition, statement.body, exit_calls)
		then
			report(statement.condition)
		end
		return true
	end

	visitor.visitBlock(cst, walker)
	return violations
end

const rule: lint_types.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
