-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `no_global_function_declarations`
const severity: lint_types.severity = `error`

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations: { lint_types.LintViolation } = {}
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	walker.visitStatFunction = function(statement: syntax.CstStatFunction): boolean
		if statement.name.tag == `global` then
			table.insert(violations, {
				lintname = name,
				location = statement.name.name.location,
				message = `Declare '{statement.name.name.text}' as a local before defining it.`,
				severity = severity,
				sourcepath = sourcepath,
			})
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
