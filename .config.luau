return {
	luau = {
		languagemode = "strict",
	},
	lute = {
		lint = {
			rulepaths = { "./src/rules/" },
			ruleconfigs = {
				duplicate_keys = { off = true },
				empty_if_block = { off = true },
				parenthesized_conditions = { off = true },
				unused_variable = { off = true },
			},
		},
	},
}
