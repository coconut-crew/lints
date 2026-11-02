-- ai marker
-- Reserve implicit self without visiting its absent source name token.
-- Track observable reads and lexical scopes without unsafe table-flow assumptions.
-- Only suggest declaration renames when references and name collisions cannot be affected.
-- Suggest '_' for short unused first iterator variables.
-- Defer renaming Workspace while the workspace-global autofix may need that binding.

const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const syntax_types = require(`@std/syntax/types`)
const utils = require(`@std/syntax/utils`)
const visitor = require(`@std/syntax/visitor`)

const name = `unused_variables`
const severity: lint_types.severity = `warning`
const unnecessary_tag: lint_types.tag = `unnecessary`

type ArgumentSet = { [number]: true? }
type WriteOnlyApis = { [string]: ArgumentSet? }
type ScopedBinding = {
	previous: syntax.CstLocal?,
	name: string,
}

--[=[
	ai generated implementation
]=]
const function write_only_apis(options: { [string]: unknown }): WriteOnlyApis
	const apis: WriteOnlyApis = {
		[`table.insert`] = { [1] = true },
		[`table.remove`] = { [1] = true },
		[`table.clear`] = { [1] = true },
		[`table.freeze`] = { [1] = true },
	}

	for api, raw_indices in options do
		const error_message =
			`Expected options for API '{api}' to be an array of positive argument indices.`
		if type(raw_indices) ~= `table` then
			(error)(error_message)
		end

		const first_dot = string.find(api, `.`, 1, true)
		if
			api == ``
			or (
				first_dot ~= nil
				and (
					first_dot == 1
					or first_dot == #api
					or string.find(api, `.`, first_dot + 1, true) ~= nil
				)
			)
		then
			(error)(
				`Invalid API '{api}' in options. Only APIs up to two non-empty levels are supported.`
			)
		end

		const indices: ArgumentSet = {}
		for option_index, argument_index in raw_indices do
			if
				type(option_index) ~= `number`
				or option_index <= 0
				or math.floor(option_index) ~= option_index
				or type(argument_index) ~= `number`
				or argument_index <= 0
				or math.floor(argument_index) ~= argument_index
			then
				(error)(error_message)
			end
			indices[argument_index] = true
		end
		apis[api] = indices
	end

	return apis
end

--[=[
	ai generated implementation
]=]
const function call_path(expression: syntax.CstExpr): string?
	if expression.tag == `global` then
		return expression.name.text
	elseif expression.tag == `indexname` and expression.expression.tag == `global` then
		return `{expression.expression.name.text}.{expression.index.text}`
	elseif
		expression.tag == `index`
		and expression.expression.tag == `global`
		and expression.index.tag == `string`
	then
		return `{expression.expression.name.text}.{expression.index.value.text}`
	end
	return nil
end

--[=[
	ai generated implementation
]=]
const function unwrap(expression: syntax.CstExpr): syntax.CstExpr
	local cursor = expression
	while cursor.tag == `group` or cursor.tag == `cast` do
		cursor = if cursor.tag == `group` then cursor.expression else cursor.operand
	end
	return cursor
end

--[=[
	ai generated implementation
]=]
const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: lint_types.RuleContext
): { lint_types.LintViolation }
	const configured_apis = write_only_apis(context.options)
	const declarations: { syntax.CstLocal } = {}
	const declared: { [syntax.CstLocal]: true? } = {}
	const used: { [syntax.CstLocal]: true? } = {}
	const ignored: { [syntax.CstLocal]: true? } = {}
	const required_modules: { [syntax.CstLocal]: true? } = {}
	const fresh_tables: { [syntax.CstLocal]: true? } = {}
	const short_iterator_keys: { [syntax.CstLocal]: true? } = {}
	const referenced: { [syntax.CstLocal]: true? } = {}
	const reassigned: { [syntax.CstLocal]: true? } = {}
	const occupied_names: { [string]: true? } = {}
	const type_prefixes: { [string]: true? } = {}
	const function_bodies: { [syntax.CstStatBlock]: syntax.CstExprFunction? } = {}
	local discarded_call: syntax.CstExpr? = nil
	local self_update: syntax.CstLocal? = nil
	local has_workspace_global = false

	-- Scan every reference, including writes skipped by the usage walker. A single
	-- replacement cannot safely rename a binding that still has references.
	const scanner = visitor.create()
	scanner.visitLocal = function(binding: syntax.CstLocal): boolean
		if binding.name == nil then
			occupied_names.self = true
			return false
		end
		occupied_names[binding.name.text] = true
		return true
	end
	scanner.visitExprLocal = function(expression: syntax.CstExprLocal): boolean
		referenced[expression[`local`]] = true
		return true
	end
	scanner.visitExprGlobal = function(expression: syntax.CstExprGlobal): boolean
		occupied_names[expression.name.text] = true
		return true
	end
	scanner.visitTypeReference = function(reference: syntax.CstTypeReference): boolean
		if reference.prefix ~= nil then
			occupied_names[reference.prefix.text] = true
			type_prefixes[reference.prefix.text] = true
		end
		return true
	end
	const function record_write(target: syntax.CstExpr): ()
		if target.tag == `local` then
			reassigned[target[`local`]] = true
		end
	end
	scanner.visitStatAssign = function(statement: syntax.CstStatAssign): boolean
		for _, target in statement.variables do
			record_write(target)
		end
		return true
	end
	scanner.visitStatCompoundAssign = function(
		statement: syntax.CstStatCompoundAssign
	): boolean
		record_write(statement.variable)
		return true
	end
	scanner.visitStatFunction = function(statement: syntax.CstStatFunction): boolean
		record_write(statement.name)
		return true
	end
	visitor.visitBlock(cst, scanner)

	-- Type prefixes are tokens rather than CstLocal references. This is the
	-- only feature here that still needs lexical name tracking.
	const visible: { [string]: syntax.CstLocal? } = {}
	const scope_bindings: { { ScopedBinding } } = {}
	const walker = visitor.create()
	walker.visitExprGlobal = function(expression: syntax.CstExprGlobal): boolean
		if expression.name.text == `workspace` then
			has_workspace_global = true
		end
		return true
	end

	--[=[
		ai generated implementation
	]=]
	const function push_scope(): ()
		const bindings: { ScopedBinding } = {}
		table.insert(scope_bindings, bindings)
	end

	--[=[
		ai generated implementation
	]=]
	const function bind(binding: syntax.CstLocal, name_override: string?): ()
		const binding_name = name_override or binding.name.text
		const previous = visible[binding_name]
		visible[binding_name] = binding
		const scope = (assert)(scope_bindings[#scope_bindings])
		scope[#scope + 1] = {
			previous = previous,
			name = binding_name,
		}
	end

	--[=[
		ai generated implementation
	]=]
	const function pop_scope(): ()
		const bindings = (assert)(table.remove(scope_bindings))
		for index = #bindings, 1, -1 do
			const scoped = bindings[index]
			visible[scoped.name] = scoped.previous
		end
	end

	--[=[
		ai generated implementation
	]=]
	const function declare(binding: syntax.CstLocal): ()
		if declared[binding] ~= true then
			declared[binding] = true
			table.insert(declarations, binding)
		end
		bind(binding)
	end

	--[=[
		ai generated implementation
	]=]
	const function mark_used(binding: syntax.CstLocal): ()
		used[binding] = true
	end

	--[=[
		ai generated implementation
	]=]
	const function visit_declaration(
		variables: syntax.CstPunctuated<syntax.CstLocal>,
		values: syntax.CstPunctuated<syntax.CstExpr>
	): ()
		for index, binding in variables do
			if binding.annotation ~= nil then
				visitor.visitType(binding.annotation, walker)
			end
			const value = values[index]
			if value ~= nil then
				-- Reassignments may run conditionally or inside deferred closures.
				-- Only an unchanged literal binding is known to stay a private table.
				fresh_tables[binding] = if unwrap(value).tag == `table`
						and reassigned[binding] ~= true
					then true
					else nil
				if utils.isRequireCall(unwrap(value)) then
					required_modules[binding] = true
				else
					ignored[binding] = true
				end
				visitor.visitExpression(value, walker)
				ignored[binding] = nil
			end
		end
		for index = #variables + 1, #values do
			visitor.visitExpression(values[index], walker)
		end
		for _, binding in variables do
			declare(binding)
		end
	end

	--[=[
		ai generated implementation
	]=]
	const function visit_write_target(target: syntax.CstExpr, depth: number): ()
		local cursor = target
		local cursor_depth = depth
		while true do
			if cursor.tag == `local` then
				if
					cursor_depth > 0
					and (cursor_depth > 1 or fresh_tables[cursor[`local`]] ~= true)
				then
					mark_used(cursor[`local`])
				end
				return
			elseif cursor.tag == `indexname` then
				cursor = cursor.expression
				cursor_depth += 1
			elseif cursor.tag == `index` then
				visitor.visitExpression(cursor.index, walker)
				cursor = cursor.expression
				cursor_depth += 1
			elseif cursor.tag == `group` then
				cursor = cursor.expression
			elseif cursor.tag == `cast` then
				visitor.visitType(cursor.annotation, walker)
				cursor = cursor.operand
			else
				visitor.visitExpression(cursor, walker)
				return
			end
		end
	end

	--[=[
		ai generated implementation
	]=]
	const function stored_closure_binding(
		target: syntax.CstExpr,
		value: syntax.CstExpr
	): syntax.CstLocal?
		const closure = unwrap(value)
		if closure.tag ~= `function` then
			return nil
		end

		if target.tag == `local` then
			return target[`local`]
		end

		if target.tag ~= `indexname` and target.tag ~= `index` then
			return nil
		end
		const receiver = unwrap(target.expression)
		if receiver.tag ~= `local` then
			return nil
		end

		const binding = receiver[`local`]
		return if fresh_tables[binding] == true then binding else nil
	end

	--[=[
		ai generated implementation
	]=]
	const function visit_assigned_value(target: syntax.CstExpr, value: syntax.CstExpr): ()
		const binding = stored_closure_binding(target, value)
		const was_ignored: true? = if binding == nil then nil else ignored[binding]
		if binding ~= nil then
			ignored[binding] = true
		end
		visitor.visitExpression(value, walker)
		if binding ~= nil then
			ignored[binding] = was_ignored
		end
	end

	--[=[
		ai generated implementation
	]=]
	walker.visitStatBlock = function(block: syntax.CstStatBlock): boolean
		push_scope()
		const func = function_bodies[block]
		if func ~= nil then
			if func.self ~= nil then
				bind(func.self, `self`)
			end
			for _, parameter in func.parameters do
				bind(parameter)
			end
		end
		return true
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatBlockEnd = function(_block: syntax.CstStatBlock): ()
		pop_scope()
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalDeclaration = function(statement: syntax.CstStatLocal): boolean
		visit_declaration(statement.variables, statement.values)
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatConstDeclaration = function(
		statement: syntax_types.CstStatConst
	): boolean
		visit_declaration(statement.variables, statement.values)
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatFor = function(statement: syntax.CstStatFor): boolean
		visitor.visitExpression(statement.from, walker)
		visitor.visitExpression(statement.to, walker)
		if statement.step ~= nil then
			visitor.visitExpression(statement.step, walker)
		end
		if statement.variable.annotation ~= nil then
			visitor.visitType(statement.variable.annotation, walker)
		end
		push_scope()
		declare(statement.variable)
		visitor.visitBlock(statement.body, walker)
		pop_scope()
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatForIn = function(statement: syntax.CstStatForIn): boolean
		for _, value in statement.values do
			visitor.visitExpression(value, walker)
		end
		for _, binding in statement.variables do
			if binding.annotation ~= nil then
				visitor.visitType(binding.annotation, walker)
			end
		end
		push_scope()
		for index, binding in statement.variables do
			if index == 1 and #binding.name.text <= 3 then
				short_iterator_keys[binding] = true
			end
			declare(binding)
		end
		visitor.visitBlock(statement.body, walker)
		pop_scope()
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatAssign = function(statement: syntax.CstStatAssign): boolean
		const paired_count = math.min(#statement.variables, #statement.values)
		for index = 1, paired_count do
			const target = statement.variables[index]
			const value = statement.values[index]
			if target.tag == `local` then
				const previous = self_update
				self_update = target[`local`]
				visit_assigned_value(target, value)
				self_update = previous
			else
				visit_write_target(target, 0)
				visit_assigned_value(target, value)
			end
		end
		for index = paired_count + 1, #statement.variables do
			const target = statement.variables[index]
			visit_write_target(target, 0)
		end
		for index = paired_count + 1, #statement.values do
			visitor.visitExpression(statement.values[index], walker)
		end
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatCompoundAssign = function(
		statement: syntax.CstStatCompoundAssign
	): boolean
		const previous = self_update
		if statement.variable.tag == `local` then
			self_update = statement.variable[`local`]
		else
			visit_write_target(statement.variable, 0)
		end
		visitor.visitExpression(statement.value, walker)
		self_update = previous
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatFunction = function(statement: syntax.CstStatFunction): boolean
		const binding = if statement.name.tag == `local`
			then statement.name[`local`]
			else nil
		const was_ignored: true? = if binding ~= nil then ignored[binding] else nil
		if statement.name.tag == `local` then
			ignored[statement.name[`local`]] = true
		else
			visit_write_target(statement.name, 0)
		end
		if statement.name.tag == `local` then
			visitor.visitExpression(statement.func, walker)
		else
			visit_assigned_value(statement.name, statement.func)
		end
		if binding ~= nil then
			ignored[binding] = was_ignored
		end
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatLocalFunction = function(
		statement: syntax.CstStatLocalFunction
	): boolean
		bind(statement.name)
		ignored[statement.name] = true
		visitor.visitExpression(statement.func, walker)
		ignored[statement.name] = nil
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatRepeat = function(statement: syntax.CstStatRepeat): boolean
		push_scope()
		for _, body_statement in statement.body.statements do
			visitor.visitStatement(body_statement, walker)
		end
		visitor.visitExpression(statement.condition, walker)
		pop_scope()
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitStatExpr = function(statement: syntax.CstStatExpr): boolean
		const previous = discarded_call
		discarded_call = unwrap(statement.expression)
		visitor.visitExpression(statement.expression, walker)
		discarded_call = previous
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitExprLocal = function(expression: syntax.CstExprLocal): boolean
		const binding = expression[`local`]
		if ignored[binding] ~= true and self_update ~= binding then
			mark_used(binding)
		end
		return false
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunction = function(expression: syntax.CstExprFunction): boolean
		push_scope()
		-- Signature annotations resolve before the parameters enter the body scope.
		function_bodies[expression.body] = expression
		return true
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitExprFunctionEnd = function(_expression: syntax.CstExprFunction): ()
		pop_scope()
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitTypeReference = function(type_reference: syntax.CstTypeReference): boolean
		const prefix = type_reference.prefix
		if prefix ~= nil then
			const binding = visible[prefix.text]
			if binding ~= nil and required_modules[binding] == true then
				mark_used(binding)
			end
		end
		return true
	end
	--[=[
		ai generated implementation
	]=]
	walker.visitExprCall = function(call: syntax.CstExprCall): boolean
		const api: string? = if call.self then nil else call_path(unwrap(call.func))
		local write_only_arguments: ArgumentSet? = if api == nil
			then nil
			else configured_apis[api]
		const table_mutator = api == `table.insert`
			or api == `table.remove`
			or api == `table.clear`
			or api == `table.freeze`
		if
			(api == `table.freeze` or api == `table.remove`)
			and call ~= discarded_call
		then
			write_only_arguments = nil
		end

		-- Passing a value to a call is observable even when its result overwrites it.
		const previous_update = self_update
		self_update = nil
		visitor.visitExpression(call.func, walker)
		for index, argument in call.arguments do
			local cursor = argument
			while cursor.tag == `group` or cursor.tag == `cast` do
				if cursor.tag == `cast` then
					visitor.visitType(cursor.annotation, walker)
					cursor = cursor.operand
				else
					cursor = cursor.expression
				end
			end
			if
				write_only_arguments ~= nil
				and write_only_arguments[index] == true
				and cursor.tag == `local`
				and (not table_mutator or fresh_tables[cursor[`local`]] == true)
			then
				continue
			end
			visitor.visitExpression(cursor, walker)
		end
		self_update = previous_update
		return false
	end

	visitor.visitBlock(cst, walker)

	const violations: { lint_types.LintViolation } = {}
	for _, binding in declarations do
		if used[binding] == true or string.sub(binding.name.text, 1, 1) == `_` then
			continue
		end
		const replacement = if short_iterator_keys[binding] == true
			then `_`
			else `_{binding.name.text}`
		const can_rename = referenced[binding] ~= true
			and occupied_names[replacement] ~= true
			and type_prefixes[binding.name.text] ~= true
			and not (has_workspace_global and binding.name.text == `Workspace`)
		table.insert(violations, {
			lintname = name,
			location = binding.name.location,
			message = `Variable '{binding.name.text}' is never used; prefix with '_' to silence.`,
			severity = severity,
			sourcepath = sourcepath,
			tags = { unnecessary_tag },
			suggestedfix = if can_rename then { fix = replacement } else nil,
		})
	end
	return violations
end

const rule: lint_types.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
