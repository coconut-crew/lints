--!strict
const lint_types = require(`@lint`)
const path = require(`@std/path`)
const syntax = require(`@std/syntax`)
const visitor = require(`@std/syntax/visitor`)

const rule_name = `type_unused`

const function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lint_types.RuleContext
): { lint_types.LintViolation }
	const lint_visit = visitor.create()

	type Ref = {
		declared: syntax.CstStatTypeAlias | syntax.CstStatTypeFunction?,
		referenced_or_exported: boolean,
		referenced_inside_self: boolean,
		scope_depth: number,
	}

	const references: { [string]: Ref? } = {}

	local type_fn: syntax.CstStatTypeFunction?

	local revisiting = true
	lint_visit.visitStatTypeAlias = function(node: syntax.CstStatTypeAlias): boolean
		if revisiting then
			revisiting = false
			return true
		end
		const name = node.name.text

		local ref: Ref
		if references[name] then
			ref = (assert)(references[name])
			ref.declared = node
		else
			const a: Ref = {
				declared = node,
				referenced_or_exported = not not node.export,
				referenced_inside_self = false,
				scope_depth = 0,
			}
			ref = a
			references[name] = ref
		end

		ref.scope_depth += 1

		revisiting = true
		visitor.visitStatement(node, lint_visit)

		ref.scope_depth -= 1

		return false
	end

	lint_visit.visitStatTypeFunction = function(node: syntax.CstStatTypeFunction): boolean
		if revisiting then
			revisiting = false
			return true
		end
		const name = node.name.text

		local ref: Ref
		if references[name] then
			ref = (assert)(references[name])
			ref.declared = node
		else
			const a: Ref = {
				declared = node,
				referenced_or_exported = not not node.export,
				referenced_inside_self = false,
				scope_depth = 0,
			}
			ref = a
			references[name] = ref
		end

		const old = type_fn
		type_fn = node
		ref.scope_depth += 1

		revisiting = true
		visitor.visitStatement(node, lint_visit)

		ref.scope_depth -= 1
		type_fn = old

		return false
	end

	lint_visit.visitTypeReference = function(node: syntax.CstTypeReference): boolean
		const name = node.name.text

		local ref: Ref
		if references[name] then
			ref = (assert)(references[name])
		else
			ref = {
				declared = nil,
				referenced_or_exported = false,
				referenced_inside_self = false,
				scope_depth = 0,
			}
		end

		if ref.scope_depth > 0 then
			ref.referenced_inside_self = true
		else
			ref.referenced_or_exported = true
		end

		return true
	end

	lint_visit.visitExprGlobal = function(node: syntax.CstExprGlobal): boolean
		if not type_fn then
			return true
		end

		const name = node.name.text

		local ref: Ref
		if references[name] then
			ref = (assert)(references[name])
		else
			ref = {
				declared = nil,
				referenced_or_exported = false,
				referenced_inside_self = false,
				scope_depth = 0,
			}
		end

		if ref.scope_depth > 0 then
			ref.referenced_inside_self = true
		else
			ref.referenced_or_exported = true
		end

		return true
	end

	visitor.visitBlock(cst, lint_visit)

	const violations: { lint_types.LintViolation } = {}

	for _type_name, ref in references do
		const declared = ref.declared
		if not declared then
			continue
		elseif ref.referenced_or_exported then
			continue
		elseif string.byte(declared.name.text) == string.byte(`_`) then
			continue
		end

		local message = `Type `
		if declared.tag == `typefunction` then
			message ..= `Function `
		end
		message ..= `'{declared.name.text}' is never used`
		if ref.referenced_inside_self then
			message ..= ` outside its own body`
		end
		message ..= `; prefix with '_' to silence.`

		table.insert(violations, {
			lintname = rule_name,
			location = declared.name.location,
			message = message,
			severity = `warning` :: "warning",
			sourcepath = sourcepath,
			suggestedfix = {
				fix = `_{declared.name.text}`,
			},
		})
	end

	return violations
end

const rule: lint_types.LintRule = {
	name = rule_name,
	lint = lint,
}

return table.freeze(rule)
