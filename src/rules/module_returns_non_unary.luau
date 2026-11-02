const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `module_returns_non_unary`
const message = `Module does not return exactly 1 value`
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

	for _, statement in return_statements do
		const expressions = statement.expressions
		const expressions_count = #expressions

		if expressions_count == 0 then
			table.insert(violations, {
				lintname = name,
				message = message,
				location = statement.location,
				severity = severity,
				sourcepath = sourcepath,
			})
			continue
		end

		const second_expression = expressions[2]
		if not second_expression then
			continue
		end

		const last_expression = expressions[#expressions]

		const start, finish = second_expression.location, last_expression.location

		table.insert(violations, {
			lintname = name,
			message = message,
			location = syntax.span.create({
				beginLine = start.beginLine,
				beginColumn = start.beginColumn,
				endLine = finish.endLine,
				endColumn = finish.endColumn,
			}),
			severity = severity,
			sourcepath = sourcepath,
		})
		continue
	end

	return violations
end

const rule: lint_types.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
