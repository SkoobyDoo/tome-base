--
-- created with TexturePacker (http://www.codeandweb.com/texturepacker)
--
-- {{smartUpdateKey}}
{% load internalpath %}

{{texture|SetTexture}}
__width = {{texture.size.width}}
__height = {{texture.size.height}}

{% for sprite in allSprites %}_G["{{sprite.fileData.absoluteFileName|InternalPath}}"] = { {{sprite|SpriteTE4}}, set="/data/gfx/{{texture.fullName}}" }
{% endfor %}
