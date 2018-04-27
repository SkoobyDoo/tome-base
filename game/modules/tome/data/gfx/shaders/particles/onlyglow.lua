-- Pits of Maj'Eyal
-- Copyright (C) 2009 - 2018 Nicolas Casalini
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

return {
	frag = "particles/onlyglow",
	vert = "particles/particle-#GL_SPECIFIC#",
	nopreprocess_vert = true,
	args = {
		tex = { texture = 0 },
	},
	clone = false,
	permanent = true,
}
