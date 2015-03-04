var InternalPath = function(input)
{
	var input = input.rawString();
	return input.replace(/.*\/data\/gfx/,"/data/gfx").replace(/=/,"/");
};
InternalPath.filterName = "InternalPath";
Library.addFilter("InternalPath");

var texture;

var SetTexture = function(t)
{
	texture = t;
	return "";
};
SetTexture.filterName = "SetTexture";
Library.addFilter("SetTexture");

var SpriteTE4 = function(sprite)
{
	var w = sprite.frameRect.width;
	var h = sprite.frameRect.height;
	var tx = sprite.frameRect.x / texture.size.width;
	var ty = sprite.frameRect.y / texture.size.height;
	var tw = sprite.frameRect.width / texture.size.width;
	var th = sprite.frameRect.height / texture.size.height;
	return "x="+tx+", y="+ty+", factorx="+tw+", factory="+th+", w="+w+", h="+h;
};
SpriteTE4.filterName = "SpriteTE4";
Library.addFilter("SpriteTE4");