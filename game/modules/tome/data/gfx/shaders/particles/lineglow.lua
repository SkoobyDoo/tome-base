-- Pits of Maj'Eyal
-- Copyright (C) 2009 - 2018 Nicolas Casalini
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

return {
	frag = "particles/glow",
	vert = "particles/particle-gl2",
	nopreprocess_vert = true,
	args = {
		tex = { texture = 0 },
	},
	clone = false,
	permanent = true,
}
