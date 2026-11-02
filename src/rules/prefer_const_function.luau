-- ai generated code

const fs = require(`@std/fs`)
const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `prefer_const_function`
const message = `Local function declarations are forbidden; use 'const function' instead.`
const severity: lint_types.severity = `warning`

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations: { lint_types.LintViolation } = {}
	local source_lines: { string }?
	const walker = visitor.create()

	-- Lute currently normalizes both `local function` and `const function`
	-- to CstStatLocalFunction, including the keyword token text. Consult the
	-- original source when it is available so fixed declarations stay clean.
	--[=[
		ai generated implementation
	]=]
	const function has_local_keyword(statement: syntax.CstStatLocalFunction): boolean
		if sourcepath == nil then
			return true
		end
		if source_lines == nil then
			source_lines = string.split(fs.readFileToString(sourcepath), `\n`)
		end

		const lines = (assert)(source_lines)
		const location = statement.localKeyword.location
		const line = lines[location.beginLine]
		return line ~= nil
			and string.sub(line, location.beginColumn, location.endColumn - 1)
				== `local`
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		statement: syntax.CstStatLocalFunction
	): boolean
		if has_local_keyword(statement) then
			table.insert(violations, {
				lintname = name,
				location = statement.localKeyword.location,
				message = message,
				severity = severity,
				sourcepath = sourcepath,
				suggestedfix = {
					fix = `const`,
				},
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
