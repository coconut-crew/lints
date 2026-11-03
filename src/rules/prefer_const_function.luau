-- ai generated code

const fs = require(`@std/fs`)
const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const lint_name = `prefer_const_function`
const lint_message = `use 'const function' instead.`
const lint_severity: lint_types.severity = `warning`

const walker = visitor.create()
const walker_violations: { lint_types.LintViolation } = {}
local walker_source_lines: { string } = {}
local walker_source_path: path.Path

-- lute prints `const function` as `local function`
-- so we gotta do this cursed shit
const function is_local(statement: syntax.CstStatLocalFunction): boolean
	const location = statement.localKeyword.location

	const line = walker_source_lines[location.beginLine]
	if not line then
		return false
	end

	return string.sub(line, location.beginColumn, location.endColumn - 1) == `local`
end

function walker.visitStatLocalFunction(node)
	if is_local(node) then
		table.insert(walker_violations, {
			lintname = lint_name,
			location = node.localKeyword.location,
			message = lint_message,
			severity = lint_severity,
			sourcepath = walker_source_path,
			suggestedfix = {
				fix = `const`,
			},
		})
	end

	return true
end

const function prefer_const_function(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	if not sourcepath then
		return {}
	end

	walker_source_path = sourcepath

	const source = fs.readFileToString(sourcepath)
	walker_source_lines = string.split(source, "\n")

	visitor.visitBlock(cst, walker)
	const violations = table.clone(walker_violations)

	table.clear(walker_violations)

	return violations
end

const rule: lint_types.LintRule = {
	name = lint_name,
	lint = prefer_const_function,
}

return table.freeze(rule)
