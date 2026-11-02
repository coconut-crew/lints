-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const printer = require(`@std/syntax/printer`)
const query = require(`@std/syntax/query`)
const syntax = require(`@std/syntax`)
const syntax_types = require(`@std/syntax/types`)
const utils = require(`@std/syntax/utils`)
const visitor = require(`@std/syntax/visitor`)

const name = `prefer_math_min_max`
const message = `Use math.min() or math.max() instead of this conditional comparison.`
const severity: lint_types.severity = `warning`

type MathMethod = "max" | "min"
type Initializers = { [syntax.CstLocal]: syntax.CstExpr? }
type ShadowedCandidates = { [syntax.CstExprIfElse]: true? }

--[=[
	ai generated implementation
]=]
const function unwrap_groups(expression: syntax.CstExpr): syntax.CstExpr
	local current = expression
	while true do
		const group = utils.isExprGroup(current)
		if group == nil then
			return current
		end
		current = group.expression
	end
end

--[=[
	ai generated implementation
]=]
const function unwrap_for_comparison(expression: syntax.CstExpr): syntax.CstExpr
	local current = expression
	while true do
		const ungrouped = unwrap_groups(current)
		const assertion = utils.isExprTypeAssertion(ungrouped)
		if assertion == nil then
			return ungrouped
		end
		current = assertion.operand
	end
end

--[=[
	ai generated implementation
]=]
const function is_number_type(annotation: syntax.CstType): boolean
	const reference = utils.isTypeReference(annotation)
	return reference ~= nil
		and reference.prefix == nil
		and reference.name.text == `number`
end

--[=[
	ai generated implementation
]=]
const function is_known_non_number(
	expression: syntax.CstExpr,
	initializers: Initializers
): boolean
	local current = expression
	const seen: { [syntax.CstLocal]: true? } = {}

	while true do
		current = unwrap_groups(current)
		const assertion = utils.isExprTypeAssertion(current)
		if assertion ~= nil then
			return not is_number_type(assertion.annotation)
		end

		if
			current.tag == `nil`
			or current.tag == `boolean`
			or current.tag == `string`
			or current.tag == `interpolatedstring`
			or current.tag == `table`
			or current.tag == `function`
		then
			return true
		end

		const local_expression = utils.isExprLocal(current)
		if local_expression == nil then
			return false
		end

		const binding = local_expression[`local`]
		if binding.annotation ~= nil then
			return not is_number_type(binding.annotation)
		end
		if seen[binding] then
			return false
		end
		seen[binding] = true

		const initializer = initializers[binding]
		if initializer == nil then
			return false
		end
		current = initializer
	end
end

--[=[
	ai generated implementation
]=]
const function is_side_effect_safe(expression: syntax.CstExpr): boolean
	const stack: { syntax.CstExpr } = { expression }
	while #stack > 0 do
		const next_expression = table.remove(stack)
		if next_expression == nil then
			break
		end
		const current = unwrap_for_comparison(next_expression)
		if
			current.tag == `nil`
			or current.tag == `boolean`
			or current.tag == `number`
			or current.tag == `integer`
			or current.tag == `string`
			or current.tag == `local`
			or current.tag == `global`
		then
			continue
		end

		const unary = utils.isExprUnary(current)
		if unary ~= nil then
			table.insert(stack, unary.operand)
			continue
		end

		const binary = utils.isExprBinary(current)
		if binary ~= nil then
			table.insert(stack, binary.lhsOperand)
			table.insert(stack, binary.rhsOperand)
			continue
		end

		const named_index = utils.isExprIndexName(current)
		if named_index ~= nil then
			table.insert(stack, named_index.expression)
			continue
		end

		const expression_index = utils.isExprIndexExpr(current)
		if expression_index ~= nil then
			table.insert(stack, expression_index.expression)
			table.insert(stack, expression_index.index)
			continue
		end

		return false
	end

	return true
end

--[=[
	ai generated implementation
]=]
const function normalized_text(expression: syntax.CstExpr): string
	const normalized =
		string.gsub(printer.printNode(unwrap_for_comparison(expression)), `%s+`, ``)
	return normalized
end

--[=[
	ai generated implementation
]=]
const function preferred_method(
	expression: syntax.CstExprIfElse,
	initializers: Initializers
): (MathMethod?, syntax.CstExprBinary?)
	if #expression.elseifs ~= 0 then
		return nil, nil
	end

	const comparison = utils.isExprBinary(unwrap_for_comparison(expression.condition))
	if comparison == nil then
		return nil, nil
	end

	const operator = comparison.operator.text
	const greater = operator == `>` or operator == `>=`
	const less = operator == `<` or operator == `<=`
	if not greater and not less then
		return nil, nil
	end

	const left = comparison.lhsOperand
	const right = comparison.rhsOperand
	if
		not is_side_effect_safe(left)
		or not is_side_effect_safe(right)
		or is_known_non_number(left, initializers)
		or is_known_non_number(right, initializers)
	then
		return nil, nil
	end

	const left_text = normalized_text(left)
	const right_text = normalized_text(right)
	const then_text = normalized_text(expression.thenExpr)
	const else_text = normalized_text(expression.elseExpr)

	if
		(greater and left_text == else_text and right_text == then_text)
		or (less and left_text == then_text and right_text == else_text)
	then
		return `min`, comparison
	end

	if
		(greater and left_text == then_text and right_text == else_text)
		or (less and left_text == else_text and right_text == then_text)
	then
		return `max`, comparison
	end

	return nil, nil
end

--[=[
	ai generated implementation
]=]
const function argument_text(expression: syntax.CstExpr): string
	local text = printer.printNode(unwrap_groups(expression))
	text = string.gsub(text, `^%s+`, ``)
	text = string.gsub(text, `%s+$`, ``)
	return text
end

--[=[
	ai generated implementation
]=]
const function bindings_declare_math(
	bindings: syntax.CstPunctuated<syntax.CstLocal>
): boolean
	for _, binding in bindings do
		if binding.name.text == `math` then
			return true
		end
	end
	return false
end

--[=[
	ai generated implementation
]=]
const function block_declares_math(block: syntax.CstStatBlock): boolean
	for _, statement in block.statements do
		const local_declaration = utils.isStatLocal(statement)
		if
			local_declaration ~= nil
			and bindings_declare_math(local_declaration.variables)
		then
			return true
		end

		const const_declaration = utils.isStatConst(statement)
		if
			const_declaration ~= nil
			and bindings_declare_math(const_declaration.variables)
		then
			return true
		end

		const local_function = utils.isStatLocalFunction(statement)
		if local_function ~= nil and local_function.name.name.text == `math` then
			return true
		end
	end

	return false
end

--[=[
	ai generated implementation
]=]
const function mark_if_candidates(root: syntax.CstNode, shadowed: ShadowedCandidates): ()
	for _, candidate in query.findAllFromRoot(root, utils.isExprIfElse).nodes do
		shadowed[candidate] = true
	end
end

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations: { lint_types.LintViolation } = {}
	const initializers: Initializers = {}
	local active_math_shadows = 0
	const block_math_shadows: { number } = {}
	const function_math_shadows: { number } = {}
	const shadowed_candidates: ShadowedCandidates = {}
	const scope_walker = visitor.create()
	const walker = visitor.create()

	local var = false
	if var then
		print(function_math_shadows)
	end

	--[=[
		ai generated implementation
	]=]
	scope_walker.visitStatRepeat = function(statement: syntax.CstStatRepeat): boolean
		if block_declares_math(statement.body) then
			mark_if_candidates(statement.condition, shadowed_candidates)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	scope_walker.visitStatFor = function(statement: syntax.CstStatFor): boolean
		if statement.variable.name.text == `math` then
			mark_if_candidates(statement.body, shadowed_candidates)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	scope_walker.visitStatForIn = function(statement: syntax.CstStatForIn): boolean
		if bindings_declare_math(statement.variables) then
			mark_if_candidates(statement.body, shadowed_candidates)
		end
		return true
	end

	visitor.visitBlock(cst, scope_walker)

	--[=[
		ai generated implementation
	]=]
	const function add_block_math_shadow(): ()
		active_math_shadows += 1
		const index = #block_math_shadows
		const shadows = block_math_shadows[index]
		if shadows ~= nil then
			block_math_shadows[index] = shadows + 1
		end
	end

	--[=[
		ai generated implementation
	]=]
	const function record_declaration(
		variables: syntax.CstPunctuated<syntax.CstLocal>,
		values: syntax.CstPunctuated<syntax.CstExpr>
	): ()
		for index, binding in variables do
			const value = values[index]
			if value ~= nil then
				initializers[binding] = value
			end
			if binding.name.text == `math` then
				add_block_math_shadow()
			end
		end
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatBlock = function(_block: syntax.CstStatBlock): boolean
		table.insert(block_math_shadows, 0)
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatBlockEnd = function(_block: syntax.CstStatBlock): ()
		const shadows = table.remove(block_math_shadows) or 0
		active_math_shadows -= shadows
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalDeclarationEnd = function(statement: syntax.CstStatLocal): ()
		record_declaration(statement.variables, statement.values)
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatConstDeclarationEnd = function(
		statement: syntax_types.CstStatConst
	): ()
		record_declaration(statement.variables, statement.values)
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		statement: syntax.CstStatLocalFunction
	): boolean
		if statement.name.name.text == `math` then
			add_block_math_shadow()
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunction = function(expression: syntax.CstExprFunction): boolean
		local shadows = 0
		for _, parameter in expression.parameters do
			if parameter.name.text == `math` then
				shadows += 1
			end
		end
		active_math_shadows += shadows
		table.insert(function_math_shadows, shadows)
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunctionEnd = function(_expression: syntax.CstExprFunction): ()
		const shadows = table.remove(function_math_shadows) or 0
		active_math_shadows -= shadows
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprIfElse = function(expression: syntax.CstExprIfElse): boolean
		if active_math_shadows ~= 0 or shadowed_candidates[expression] then
			return true
		end

		const method, comparison = preferred_method(expression, initializers)
		if method == nil or comparison == nil then
			return true
		end

		table.insert(violations, {
			lintname = name,
			location = expression.location,
			message = message,
			severity = severity,
			sourcepath = sourcepath,
			suggestedfix = {
				fix = `math.{method}({argument_text(comparison.lhsOperand)}, {argument_text(
					comparison.rhsOperand
				)})`,
			},
		})
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
