local mod = get_mod("CustomFlames")

local widgets = {
	{
		setting_id = "feature_toggles",
		type = "group",
		sub_widgets = {
			{
				setting_id = "flamer_color",
				type = "dropdown",
				default_value = 1,
				tooltip = "flamer_color_tooltip",
				options = {
					{text = "flame_color1", value = 1, show_widgets = {}},
					{text = "flame_color2", value = 2, show_widgets = {}},
					{text = "flame_color3", value = 3, show_widgets = {}},
					{text = "flame_color4", value = 4, show_widgets = {}},
					{text = "flame_color5", value = 5, show_widgets = {}},
				},
			},
			{
				setting_id = "flamestaff_color",
				type = "dropdown",
				default_value = 1,
				tooltip = "flamestaff_color_tooltip",
				options = {
					{text = "flame_color1", value = 1, show_widgets = {}},
					{text = "flame_color2", value = 2, show_widgets = {}},
					{text = "flame_color3", value = 3, show_widgets = {}},
					{text = "flame_color4", value = 4, show_widgets = {}},
					{text = "flame_color5", value = 5, show_widgets = {}},
				},
			},
			{
				setting_id = "flamer_burst",
				type = "dropdown",
				default_value = 1,
				tooltip = "flamer_burst_tooltip",
				options = {
					{text = "flamer_burst1", value = 1, show_widgets = {}},
					{text = "flamer_burst2", value = 2, show_widgets = {}},
					{text = "flamer_burst3", value = 3, show_widgets = {}},
					{text = "flamer_burstD", value = 999, show_widgets = {}},
				},
			},
			{
				setting_id = "flamer_held",
				type = "dropdown",
				default_value = 1,
				tooltip = "flamer_held_tooltip",
				options = {
					{text = "flamer_held1", value = 1, show_widgets = {}},
					{text = "flamer_held2", value = 2, show_widgets = {}},
					{text = "flamer_held3", value = 3, show_widgets = {}},
					{text = "flamer_heldD", value = 999, show_widgets = {}},
				},
			},
			{
				setting_id = "flamestaff_burst",
				type = "dropdown",
				default_value = 1,
				tooltip = "flamestaff_burst_tooltip",
				options = {
					{text = "flamestaff_burst1", value = 1, show_widgets = {}},
					{text = "flamestaff_burst2", value = 2, show_widgets = {}},
					{text = "flamestaff_burst3", value = 3, show_widgets = {}},
					{text = "flamestaff_burstD", value = 999, show_widgets = {}},
				},
			},
			{
				setting_id = "flamestaff_held",
				type = "dropdown",
				default_value = 1,
				tooltip = "flamestaff_held_tooltip",
				options = {
					{text = "flamestaff_held1", value = 1, show_widgets = {}},
					{text = "flamestaff_held2", value = 2, show_widgets = {}},
					{text = "flamestaff_held3", value = 3, show_widgets = {}},
					{text = "flamestaff_heldD", value = 999, show_widgets = {}},
				},
			},
		},
	},
}
return {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}
