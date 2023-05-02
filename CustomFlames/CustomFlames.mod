return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`CustomFlames` encountered an error loading the Darktide Mod Framework.")

		new_mod("CustomFlames", {
			mod_script       = "CustomFlames/scripts/mods/CustomFlames/CustomFlames",
			mod_data         = "CustomFlames/scripts/mods/CustomFlames/CustomFlames_data",
			mod_localization = "CustomFlames/scripts/mods/CustomFlames/CustomFlames_localization",
		})
	end,
	packages = {},
}
