-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const printer = require(`@std/syntax/printer`)
const syntax = require(`@std/syntax`)
const syntax_types = require(`@std/syntax/types`)
const utils = require(`@std/syntax/utils`)
const visitor = require(`@std/syntax/visitor`)

const name = `no_floating_point_equality`
const message =
	`Compare floating-point results within a tolerance instead of for exact equality.`
const severity: lint_types.severity = `warning`
const maximum_safe_integer = 9_007_199_254_740_991

const arithmetic_operators: { [string]: true? } = {
	[`%`] = true,
	[`*`] = true,
	[`+`] = true,
	[`-`] = true,
	[`/`] = true,
	[`//`] = true,
	[`^`] = true,
}

type Analysis = {
	read constant: number?,
	read floating: boolean,
}

type AnalysisFrame = {
	read expanded: boolean,
	read expression: syntax.CstExpr,
}

type ConstInitializers = { [syntax.CstLocal]: syntax.CstExpr? }

type OrientedComparison = {
	read above: boolean,
	read expression: syntax.CstExpr,
	read threshold: syntax.CstExpr,
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
const function divide_decimal_by_five(digits: string): string?
	const last = string.sub(digits, -1)
	if last ~= `0` and last ~= `5` then
		return nil
	end

	const quotient: { string } = {}
	local remainder = 0
	for index = 1, #digits do
		const digit = string.byte(digits, index) - string.byte(`0`)
		const value = remainder * 10 + digit
		const quotient_digit = value // 5
		remainder = value % 5
		if quotient_digit ~= 0 or #quotient > 0 then
			table.insert(quotient, tostring(quotient_digit))
		end
	end

	return if #quotient == 0 then `0` else table.concat(quotient)
end

--[=[
	ai generated implementation
]=]
const function is_exact_decimal(raw: string): boolean
	const without_separators = string.gsub(raw, `_`, ``)
	const normalized = string.lower(without_separators)
	if string.sub(normalized, 1, 2) == `0x` or string.sub(normalized, 1, 2) == `0b` then
		return true
	end

	const exponent_begin = string.find(normalized, `e`, 1, true)
	const coefficient = if exponent_begin == nil
		then normalized
		else string.sub(normalized, 1, exponent_begin - 1)
	const exponent = if exponent_begin == nil
		then 0
		else tonumber(string.sub(normalized, exponent_begin + 1))
	if exponent == nil then
		return false
	end

	const decimal_begin = string.find(coefficient, `.`, 1, true)
	const fraction_length = if decimal_begin == nil
		then 0
		else #coefficient - decimal_begin
	const digits = string.gsub(coefficient, `%.`, ``)
	if string.match(digits, `^0+$`) ~= nil then
		return true
	end

	const scale = fraction_length - exponent
	if scale <= 0 then
		return true
	end
	if scale > #digits * 2 then
		return false
	end

	local numerator = digits
	for _ = 1, scale do
		const quotient = divide_decimal_by_five(numerator)
		if quotient == nil then
			return false
		end
		numerator = quotient
	end

	return true
end

--[=[
	ai generated implementation
]=]
const function numeric_literal_value(expression: syntax.CstExpr): number?
	const current = unwrap(expression)
	if current.tag == `number` or current.tag == `integer` then
		return current.value
	end

	const unary = utils.isExprUnary(current)
	if unary == nil or unary.operator.text ~= `-` then
		return nil
	end

	const operand = unwrap(unary.operand)
	if operand.tag ~= `number` and operand.tag ~= `integer` then
		return nil
	end
	return -operand.value
end

--[=[
	ai generated implementation
]=]
const function is_safe_integer(value: number): boolean
	return value == math.floor(value) and math.abs(value) <= maximum_safe_integer
end

--[=[
	ai generated implementation
]=]
const function constant_binary_value(
	operator: string,
	left: number,
	right: number
): number?
	if operator == `+` then
		return left + right
	elseif operator == `-` then
		return left - right
	elseif operator == `*` then
		return left * right
	elseif operator == `/` then
		return if right == 0 then nil else left / right
	elseif operator == `//` then
		return if right == 0 then nil else left // right
	elseif operator == `%` then
		return if right == 0 then nil else left % right
	elseif operator == `^` then
		return left ^ right
	end

	return nil
end

--[=[
	ai generated implementation
]=]
const function division_is_inexact(expression: syntax.CstExprBinary): boolean
	const numerator = numeric_literal_value(expression.lhsOperand)
	const denominator = numeric_literal_value(expression.rhsOperand)
	if
		numerator == nil
		or denominator == nil
		or denominator == 0
		or not is_safe_integer(numerator)
		or not is_safe_integer(denominator)
	then
		return false
	end

	local odd_denominator = math.abs(denominator)
	while odd_denominator % 2 == 0 do
		odd_denominator /= 2
	end

	return math.abs(numerator) % odd_denominator ~= 0
end

--[=[
	ai generated implementation
]=]
const function collect_const_initializers(cst: syntax.CstStatBlock): ConstInitializers
	const initializers: ConstInitializers = {}
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatConstDeclaration = function(
		statement: syntax_types.CstStatConst
	): boolean
		for index, binding in statement.variables do
			const value = statement.values[index]
			if value ~= nil then
				initializers[binding] = value
			end
		end
		return true
	end

	visitor.visitBlock(cst, walker)
	return initializers
end

--[=[
	ai generated implementation
]=]
const function expression_dependency(
	expression: syntax.CstExpr,
	initializers: ConstInitializers
): (syntax.CstExpr?, syntax.CstExpr?)
	const local_expression = utils.isExprLocal(expression)
	if local_expression ~= nil then
		return initializers[local_expression[`local`]], nil
	end

	const unary = utils.isExprUnary(expression)
	if unary ~= nil and unary.operator.text == `-` then
		return unwrap(unary.operand), nil
	end

	const binary = utils.isExprBinary(expression)
	if binary ~= nil and arithmetic_operators[binary.operator.text] then
		return unwrap(binary.lhsOperand), unwrap(binary.rhsOperand)
	end

	return nil, nil
end

--[=[
	ai generated implementation
]=]
const function child_analysis(
	analyses: { [syntax.CstExpr]: Analysis? },
	expression: syntax.CstExpr
): Analysis
	return analyses[unwrap(expression)] or {
		constant = nil,
		floating = false,
	}
end

--[=[
	ai generated implementation
]=]
const function compute_analysis(
	expression: syntax.CstExpr,
	initializers: ConstInitializers,
	analyses: { [syntax.CstExpr]: Analysis? }
): Analysis
	if expression.tag == `integer` then
		return {
			constant = expression.value,
			floating = false,
		}
	elseif expression.tag == `number` then
		const raw = expression.token.text
		return {
			constant = expression.value,
			floating = (
				string.find(raw, `.`, 1, true) ~= nil
				or string.find(string.lower(raw), `e`, 1, true) ~= nil
			) and not is_exact_decimal(raw),
		}
	end

	const local_expression = utils.isExprLocal(expression)
	if local_expression ~= nil then
		const initializer = initializers[local_expression[`local`]]
		return if initializer == nil
			then { constant = nil, floating = false }
			else child_analysis(analyses, initializer)
	end

	const unary = utils.isExprUnary(expression)
	if unary ~= nil and unary.operator.text == `-` then
		const operand = child_analysis(analyses, unary.operand)
		return {
			constant = if operand.constant == nil then nil else -operand.constant,
			floating = operand.floating,
		}
	end

	const binary = utils.isExprBinary(expression)
	if binary == nil or not arithmetic_operators[binary.operator.text] then
		return { constant = nil, floating = false }
	end

	const left = child_analysis(analyses, binary.lhsOperand)
	const right = child_analysis(analyses, binary.rhsOperand)
	const constant = if left.constant == nil or right.constant == nil
		then nil
		else constant_binary_value(
			binary.operator.text,
			left.constant,
			right.constant
		)
	if constant ~= nil and is_safe_integer(constant) then
		return { constant = constant, floating = false }
	end

	local floating = false
	if binary.operator.text == `/` then
		floating = division_is_inexact(binary) or left.floating or right.floating
	elseif binary.operator.text ~= `//` then
		floating = left.floating or right.floating
	end

	return {
		constant = constant,
		floating = floating,
	}
end

--[=[
	ai generated implementation
]=]
const function analyze_expression(
	expression: syntax.CstExpr,
	initializers: ConstInitializers
): Analysis
	const root = unwrap(expression)
	const analyses: { [syntax.CstExpr]: Analysis? } = {}
	const visiting: { [syntax.CstExpr]: true? } = {}
	const stack: { AnalysisFrame } = {
		{ expanded = false, expression = root },
	}

	while #stack > 0 do
		const frame = table.remove(stack)
		if frame == nil then
			break
		end
		const current = unwrap(frame.expression)
		if analyses[current] ~= nil then
			continue
		end

		if frame.expanded then
			analyses[current] = compute_analysis(current, initializers, analyses)
			visiting[current] = nil
			continue
		end

		visiting[current] = true
		table.insert(stack, {
			expanded = true,
			expression = current,
		})
		const first, second = expression_dependency(current, initializers)
		if second ~= nil then
			const dependency = unwrap(second)
			if analyses[dependency] == nil and not visiting[dependency] then
				table.insert(stack, {
					expanded = false,
					expression = dependency,
				})
			end
		end
		if first == nil then
			continue
		end

		const dependency = unwrap(first)
		if analyses[dependency] ~= nil or visiting[dependency] then
			continue
		end

		table.insert(stack, {
			expanded = false,
			expression = dependency,
		})
	end

	return analyses[root] or { constant = nil, floating = false }
end

--[=[
	ai generated implementation
]=]
const function expression_is_floating(
	expression: syntax.CstExpr,
	initializers: ConstInitializers
): boolean
	return analyze_expression(expression, initializers).floating
end

--[=[
	ai generated implementation
]=]
const function normalized_expression_text(expression: syntax.CstExpr): string
	const normalized = string.gsub(printer.printNode(unwrap(expression)), `%s+`, ``)
	return normalized
end

--[=[
	ai generated implementation
]=]
const function comparison_orientations(
	expression: syntax.CstExprBinary
): { OrientedComparison }
	const above = expression.operator.text == `>` or expression.operator.text == `>=`
	return {
		{
			above = above,
			expression = expression.lhsOperand,
			threshold = expression.rhsOperand,
		},
		{
			above = not above,
			expression = expression.rhsOperand,
			threshold = expression.lhsOperand,
		},
	}
end

--[=[
	ai generated implementation
]=]
const function indirect_comparison_operands(
	expression: syntax.CstExprBinary
): (syntax.CstExpr?, syntax.CstExpr?)
	const left = utils.isExprBinary(unwrap(expression.lhsOperand))
	const right = utils.isExprBinary(unwrap(expression.rhsOperand))
	if left == nil or right == nil then
		return nil, nil
	end

	const left_operator = left.operator.text
	const right_operator = right.operator.text
	const accepted = if expression.operator.text == `and`
		then (left_operator == `<=` or left_operator == `>=`)
			and (right_operator == `<=` or right_operator == `>=`)
		elseif expression.operator.text == `or` then (
			left_operator == `<` or left_operator == `>`
		) and (right_operator == `<` or right_operator == `>`)
		else false
	if not accepted then
		return nil, nil
	end

	for _, left_orientation in comparison_orientations(left) do
		for _, right_orientation in comparison_orientations(right) do
			if
				left_orientation.above ~= right_orientation.above
				and normalized_expression_text(left_orientation.expression) == normalized_expression_text(
					right_orientation.expression
				)
				and normalized_expression_text(left_orientation.threshold)
					== normalized_expression_text(right_orientation.threshold)
			then
				return left_orientation.expression, left_orientation.threshold
			end
		end
	end

	return nil, nil
end

--[=[
	ai generated implementation
]=]
const function identifier_name(expression: syntax.CstExpr): string?
	const current = unwrap(expression)
	const local_expression = utils.isExprLocal(current)
	if local_expression ~= nil then
		return local_expression.token.text
	end

	const global = utils.isExprGlobal(current)
	return if global == nil then nil else global.name.text
end

--[=[
	ai generated implementation
]=]
const function assertion_operands(
	call: syntax.CstExprCall
): (syntax.CstExpr?, syntax.CstExpr?)
	const member = utils.isExprIndexName(unwrap(call.func))
	if
		member == nil
		or member.accessor.text ~= `.`
		or (member.index.text ~= `eq` and member.index.text ~= `neq`)
	then
		return nil, nil
	end

	local receiver = member.expression
	const negation = utils.isExprIndexName(unwrap(receiver))
	if
		negation ~= nil
		and negation.accessor.text == `.`
		and negation.index.text == `never`
	then
		receiver = negation.expression
	end

	if identifier_name(receiver) ~= `asserts` then
		return nil, nil
	end

	return call.arguments[1], call.arguments[2]
end

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const initializers = collect_const_initializers(cst)
	const violations: { lint_types.LintViolation } = {}
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	const function report(location: syntax.Span): ()
		table.insert(violations, {
			lintname = name,
			location = location,
			message = message,
			severity = severity,
			sourcepath = sourcepath,
		})
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprBinary = function(expression: syntax.CstExprBinary): boolean
		const operator = expression.operator.text
		if operator == `==` or operator == `~=` then
			if
				expression_is_floating(expression.lhsOperand, initializers)
				or expression_is_floating(expression.rhsOperand, initializers)
			then
				report(expression.location)
			end
			return true
		end

		if operator == `and` or operator == `or` then
			const value, threshold = indirect_comparison_operands(expression)
			if
				value ~= nil
				and threshold ~= nil
				and (
					expression_is_floating(value, initializers)
					or expression_is_floating(threshold, initializers)
				)
			then
				report(expression.location)
			end
		end

		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprCall = function(call: syntax.CstExprCall): boolean
		const actual, expected = assertion_operands(call)
		if
			actual ~= nil
			and expected ~= nil
			and (
				expression_is_floating(actual, initializers)
				or expression_is_floating(expected, initializers)
			)
		then
			report(call.location)
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
