-- ai generated code

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const name = `unused_function`
const severity: lint_types.severity = `warning`
const unnecessary_tag: lint_types.tag = `unnecessary`

type FunctionInfo = {
	declaration: syntax.CstToken<string>?,
	read name: string,
	scope_depth: number,
	used_outside_self: boolean,
	used_recursively: boolean,
}

--[=[
	ai generated implementation
]=]
const function new_function_info(function_name: string): FunctionInfo
	return {
		declaration = nil,
		name = function_name,
		scope_depth = 0,
		used_outside_self = false,
		used_recursively = false,
	}
end

--[=[
	ai generated implementation
]=]
const function global_info(
	globals: { [string]: FunctionInfo? },
	function_name: string
): FunctionInfo
	const info = globals[function_name]
	if info ~= nil then
		return info
	end

	const created = new_function_info(function_name)
	globals[function_name] = created
	return created
end

--[=[
	ai generated implementation
]=]
const function mark_used(info: FunctionInfo): ()
	if info.scope_depth > 0 then
		info.used_recursively = true
	else
		info.used_outside_self = true
	end
end

--[=[
	ai generated implementation
]=]
const function violation_message(info: FunctionInfo): string
	if info.used_recursively then
		return `Function '{info.name}' is never used outside its own body; prefix with '_' to silence`
	end

	return `Function '{info.name}' is never used; prefix with '_' to silence`
end

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const locals: { [syntax.CstLocal]: FunctionInfo? } = {}
	const globals: { [string]: FunctionInfo? } = {}
	const declarations: { FunctionInfo } = {}
	const walker = visitor.create()

	--[=[
		ai generated implementation
	]=]
	const function visit_assignment_target(target: syntax.CstExpr): ()
		-- A direct variable target is only written. Indexed targets still read
		-- their base and index expressions while locating the destination.
		if target.tag == `local` or target.tag == `global` then
			return
		end

		visitor.visitExpression(target, walker)
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatAssign = function(statement: syntax.CstStatAssign): boolean
		for _, target in statement.variables do
			visit_assignment_target(target)
		end
		for _, value in statement.values do
			visitor.visitExpression(value, walker)
		end
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		statement: syntax.CstStatLocalFunction
	): boolean
		const info = new_function_info(statement.name.name.text)
		info.declaration = statement.name.name
		info.scope_depth = 1
		locals[statement.name] = info
		table.insert(declarations, info)

		visitor.visitExpression(statement.func, walker)
		info.scope_depth = 0
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatFunction = function(statement: syntax.CstStatFunction): boolean
		if statement.name.tag ~= `global` then
			if statement.name.tag == `local` then
				-- Reassigning a local with declaration syntax is a write to the
				-- binding, not a use of its previous function value.
				visitor.visitExpression(statement.func, walker)
				return false
			end
			return true
		end

		const function_name = statement.name.name.text
		const info = global_info(globals, function_name)
		if info.declaration == nil then
			table.insert(declarations, info)
		end
		info.declaration = statement.name.name
		info.scope_depth += 1

		-- Visit only the function expression. The declaration target is a
		-- write, not an outside use of the function being declared.
		visitor.visitExpression(statement.func, walker)
		info.scope_depth -= 1
		return false
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprLocal = function(expression: syntax.CstExprLocal): boolean
		const info = locals[expression[`local`]]
		if info ~= nil then
			mark_used(info)
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitExprGlobal = function(expression: syntax.CstExprGlobal): boolean
		mark_used(global_info(globals, expression.name.text))
		return true
	end

	visitor.visitBlock(cst, walker)

	const violations: { lint_types.LintViolation } = {}
	for _, info in declarations do
		const declaration = info.declaration
		if
			declaration == nil
			or info.used_outside_self
			or string.sub(info.name, 1, 1) == `_`
		then
			continue
		end

		table.insert(violations, {
			lintname = name,
			location = declaration.location,
			message = violation_message(info),
			severity = severity,
			sourcepath = sourcepath,
			tags = { unnecessary_tag },
		})
	end

	return violations
end

const rule: lint_types.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
