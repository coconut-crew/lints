const lint_types = require(`@lint`)
const pathlib = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const lintname = `reassigned_screaming_snake_case`
const lint_message = `Uppercase variables should not be reassigned.`
const severity = `warning`

const function is_uppercase(name: string): boolean
	return string.upper(name) == name
end

const walker = visitor.create()
const walker_violations: { lint_types.LintViolation } = {}
local walker_sourcepath

const function process_assigned(variable: syntax.CstExpr): ()
	local name
	if variable.tag == "local" then
		name = variable.token.text
	elseif variable.tag == "global" then
		name = variable.name.text
	else
		return
	end

	if not is_uppercase(name) then
		return
	end

	table.insert(walker_violations, {
		lintname = lintname,
		location = variable.location,
		message = lint_message,
		severity = severity,
		sourcepath = walker_sourcepath,
	})
end

function walker.visitStatAssign(node)
	for _, variable in node.variables do
		process_assigned(variable)
	end
end

function walker.visitStatCompoundAssign(node)
	process_assigned(node.variable)
end

const function reassigned_screaming_snake_case(
	cst: syntax.CstStatBlock,
	sourcepath: pathlib.Path?,
	context: lint_types.RuleContext
)
	walker_sourcepath = sourcepath

	visitor.visit(cst, walker)
	const violations = table.clone(walker_violations)

	table.clear(walker_violations)

	return violations
end

const rule: lint_types.LintRule = {
	name = lintname,
	lint = reassigned_screaming_snake_case,
}

return rule
