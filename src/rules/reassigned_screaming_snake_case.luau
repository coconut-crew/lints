-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const utils = require(`@std/syntax/utils`)
const visitor = require(`@std/syntax/visitor`)

const name = `reassigned_screaming_snake_case`
const message = `Variables named with SCREAMING_SNAKE_CASE must not be reassigned.`
const severity: lint_types.severity = `warning`

--[=[
	ai generated implementation
]=]
const function is_screaming_snake_case(identifier: string): boolean
	return string.upper(identifier) == identifier
		and string.match(identifier, `^_*[A-Z][A-Z0-9_]*$`) ~= nil
end

--[=[
	ai generated implementation
]=]
const function assigned_identifier(expression: syntax.CstExpr): syntax.CstToken<string>?
	const local_expression = utils.isExprLocal(expression)
	if local_expression ~= nil then
		return local_expression.token
	end

	const global_expression = utils.isExprGlobal(expression)
	if global_expression ~= nil then
		return global_expression.name
	end

	return nil
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

	--[=[
		ai generated implementation
	]=]
	const function check(expression: syntax.CstExpr): ()
		const identifier = assigned_identifier(expression)
		if identifier == nil or not is_screaming_snake_case(identifier.text) then
			return
		end

		table.insert(violations, {
			lintname = name,
			location = identifier.location,
			message = message,
			severity = severity,
			sourcepath = sourcepath,
		})
	end

	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatAssign = function(statement: syntax.CstStatAssign): boolean
		for _, variable in statement.variables do
			check(variable)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatCompoundAssign = function(
		statement: syntax.CstStatCompoundAssign
	): boolean
		check(statement.variable)
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
