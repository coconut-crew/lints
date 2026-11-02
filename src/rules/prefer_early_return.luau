-- ai marker
-- Require four code lines and suggest return, continue, or existing break guards only on safe tail paths.

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `prefer_early_return`
const minimum_code_lines = 4
const severity: lint_types.severity = `warning`

type Exit = "return" | "continue" | "break"

const function is_large_body(
	block: syntax.CstStatBlock,
	context: lint_types.RuleContext
): boolean
	-- Retain the old option as an additional filter; it cannot lower the four-line minimum.
	const maximum_statements = context.options.maximum_statements
	if
		type(maximum_statements) == `number`
		and maximum_statements >= 0
		and #block.statements <= maximum_statements
	then
		return false
	end

	const lines: { [number]: boolean } = {}
	local count = 0
	const walker = visitor.create()
	walker.visitToken = function(token: syntax.CstToken): boolean
		-- Trivia and the contents of multiline strings do not add code lines.
		const line = token.location.beginLine
		if not lines[line] then
			lines[line] = true
			count += 1
		end
		return false
	end
	visitor.visitBlock(block, walker)
	return count >= minimum_code_lines
end

const function single_exit(block: syntax.CstStatBlock, inside_loop: boolean): Exit?
	if #block.statements ~= 1 then
		return nil
	end

	const statement = block.statements[1]
	if statement.tag == `return` then
		return `return`
	elseif inside_loop and (statement.tag == `break` or statement.tag == `continue`) then
		return statement.tag
	end
	return nil
end

const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: lint_types.RuleContext
): { lint_types.LintViolation }
	const violations: { lint_types.LintViolation } = {}

	const function report(statement: syntax.CstStatIf, exit: Exit, invert: boolean): ()
		table.insert(violations, {
			lintname = name,
			location = statement.ifKeyword.location,
			message = if invert
				then `Invert the condition and use an early {exit} to remove nesting from the main body.`
				else `The then branch exits with {exit}. Remove the else and move its body after the guard.`,
			severity = severity,
			sourcepath = sourcepath,
		})
	end

	const function inspect_tail(
		block: syntax.CstStatBlock,
		fallthrough: Exit,
		inside_loop: boolean
	): ()
		const statement = block.statements[#block.statements]
		if statement == nil then
			return
		end

		-- Only tail paths can be flattened without skipping work or exposing locals to later code.
		if statement.tag == `do` then
			inspect_tail(statement.body, fallthrough, inside_loop)
		elseif statement.tag == `conditional` then
			const else_block = statement.elseBlock
			if #statement.elseifs == 0 then
				if else_block == nil then
					if is_large_body(statement.thenBlock, context) then
						report(statement, fallthrough, true)
					end
				else
					const then_exit = single_exit(statement.thenBlock, inside_loop)
					const else_exit = single_exit(else_block, inside_loop)
					if then_exit ~= nil and is_large_body(else_block, context) then
						report(statement, then_exit, false)
					elseif
						else_exit ~= nil and is_large_body(statement.thenBlock, context)
					then
						report(statement, else_exit, true)
					end
				end
			end

			inspect_tail(statement.thenBlock, fallthrough, inside_loop)
			for _, clause in statement.elseifs do
				inspect_tail(clause.thenBlock, fallthrough, inside_loop)
			end
			if else_block ~= nil then
				inspect_tail(else_block, fallthrough, inside_loop)
			end
		end
	end

	const walker = visitor.create()
	walker.visitExprFunction = function(expression: syntax.CstExprFunction): boolean
		inspect_tail(expression.body, `return`, false)
		return true
	end
	walker.visitStatWhile = function(statement: syntax.CstStatWhile): boolean
		inspect_tail(statement.body, `continue`, true)
		return true
	end
	walker.visitStatFor = function(statement: syntax.CstStatFor): boolean
		inspect_tail(statement.body, `continue`, true)
		return true
	end
	walker.visitStatForIn = function(statement: syntax.CstStatForIn): boolean
		inspect_tail(statement.body, `continue`, true)
		return true
	end
	-- Repeat conditions share the body's scope: hoisting locals could change the condition's bindings.
	visitor.visitBlock(cst, walker)
	return violations
end

const rule: lint_types.LintRule = { name = name, lint = lint }

return table.freeze(rule)
