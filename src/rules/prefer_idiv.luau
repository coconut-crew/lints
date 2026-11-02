-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const printer = require(`@std/syntax/printer`)
const query = require(`@std/syntax/query`)
const syntax = require(`@std/syntax`)
const utils = require(`@std/syntax/utils`)

const name = `prefer_idiv`
const message = `Use '//' instead of math.floor(x / y) for integer division.`
const severity: lint_types.severity = `warning`

type Division = {
	read dividend: syntax.CstExpr,
	read divisor: syntax.CstExpr?,
	read literal_divisor: number?,
}

--[=[
	ai generated implementation
]=]
const function unwrap(expression: syntax.CstExpr): syntax.CstExpr
	local current = expression
	while true do
		const group = utils.isExprGroup(current)
		if group ~= nil then
			current = group.expression
			continue
		end

		const assertion = utils.isExprTypeAssertion(current)
		if assertion ~= nil then
			current = assertion.operand
			continue
		end

		return current
	end
end

--[=[
	ai generated implementation
]=]
const function is_global_math(expression: syntax.CstExpr): boolean
	const global = utils.isExprGlobal(unwrap(expression))
	return global ~= nil and global.name.text == `math`
end

--[=[
	ai generated implementation
]=]
const function is_math_floor_call(call: syntax.CstExprCall): boolean
	const function_expression = unwrap(call.func)
	const named_index = utils.isExprIndexName(function_expression)
	if named_index ~= nil then
		return named_index.accessor.text == `.`
			and named_index.index.text == `floor`
			and is_global_math(named_index.expression)
	end

	const expression_index = utils.isExprIndexExpr(function_expression)
	if expression_index == nil or not is_global_math(expression_index.expression) then
		return false
	end

	const index = utils.isExprConstantString(unwrap(expression_index.index))
	return index ~= nil and index.value.text == `floor`
end

--[=[
	ai generated implementation
]=]
const function reciprocal_divisor(expression: syntax.CstExpr): number?
	const literal = unwrap(expression)
	if literal.tag ~= `number` and literal.tag ~= `integer` then
		return nil
	end

	const value = literal.value
	if value <= 0 or value >= 1 then
		return nil
	end

	const divisor = 1 / value
	if
		divisor ~= divisor
		or math.abs(divisor) == math.huge
		or divisor ~= math.floor(divisor)
	then
		return nil
	end

	return divisor
end

--[=[
	ai generated implementation
]=]
const function expression_text(expression: syntax.CstExpr): string
	local text = printer.printNode(expression)
	text = string.gsub(text, `^%s+`, ``)
	text = string.gsub(text, `%s+$`, ``)
	return text
end

--[=[
	ai generated implementation
]=]
const function preferred_division(call: syntax.CstExprCall): Division?
	if not is_math_floor_call(call) or #call.arguments ~= 1 then
		return nil
	end

	const argument = call.arguments[1]
	if argument == nil then
		return nil
	end

	const expression = utils.isExprBinary(unwrap(argument))
	if expression == nil then
		return nil
	end

	if expression.operator.text == `/` then
		return {
			dividend = expression.lhsOperand,
			divisor = expression.rhsOperand,
			literal_divisor = nil,
		}
	end

	if expression.operator.text ~= `*` then
		return nil
	end

	const right_divisor = reciprocal_divisor(expression.rhsOperand)
	if right_divisor ~= nil then
		return {
			dividend = expression.lhsOperand,
			divisor = nil,
			literal_divisor = right_divisor,
		}
	end

	const left_divisor = reciprocal_divisor(expression.lhsOperand)
	if left_divisor == nil then
		return nil
	end

	return {
		dividend = expression.rhsOperand,
		divisor = nil,
		literal_divisor = left_divisor,
	}
end

--[=[
	ai generated implementation
]=]
const function division_fix(division: Division): string
	const divisor = division.divisor
	const divisor_text = if divisor ~= nil
		then expression_text(divisor)
		else tostring(division.literal_divisor)

	return `{expression_text(division.dividend)} // {divisor_text}`
end

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	return query.findAllFromRoot(cst, utils.isExprCall):flatMap(
		--[=[
				ai generated implementation
			]=]
		function(call: syntax.CstExprCall): { lint_types.LintViolation }
			const division = preferred_division(call)
			if division == nil then
				return {}
			end

			return {
				{
					lintname = name,
					location = call.location,
					message = message,
					severity = severity,
					sourcepath = sourcepath,
					suggestedfix = {
						fix = division_fix(division),
					},
				},
			}
		end
	).nodes
end

const rule: lint_types.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
