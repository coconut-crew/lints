const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `multiple_top_level_returns`
const message = `Please do not add multiple top level returns to a file.`
const severity: lint_types.severity = `warning`

const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations: { lint_types.LintViolation } = {}
	const walker = visitor.create()

	function walker.visitExprFunction(node)
		return false
	end

	const return_statements: { syntax.CstStatReturn } = {}
	function walker.visitStatReturn(node)
		table.insert(return_statements, node)
		return true
	end

	visitor.visitBlock(cst, walker)

	for i = 1, #return_statements - 1 do
		const statement = return_statements[i]

		table.insert(violations, {
			lintname = name,
			message = message,
			location = statement.returnKeyword.location,
			severity = severity,
		})
	end

	return violations
end

const rule: lint_types.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
