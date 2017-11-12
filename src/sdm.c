/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2017 Nicolas Casalini

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Nicolas Casalini "DarkGod"
    darkgod@te4.org
*/

#include "lua.h"
#include "types.h"
#include "display.h"
#include "sdm.h"
#include <math.h>

typedef struct
{
	int x, y;
} Vector;

static inline float clamp(float val, float min, float max) { return val < min ? min : (val > max ? max : val); }

void build_sdm_ex(const unsigned char *texData, int srcWidth, int srcHeight, unsigned char *sdmTexData, int dstWidth, int dstHeight, int dstx, int dsty)
{

	int maxSize = dstWidth > dstHeight ? dstWidth : dstHeight;
	int minSize = dstWidth < dstHeight ? dstWidth : dstHeight;

	Vector *pixelStack = (Vector *)malloc(dstWidth * dstHeight * sizeof(Vector));
	Vector *vectorMap = (Vector *)malloc(dstWidth * dstHeight * sizeof(Vector));
	int *pixelStackIndex = (int *) malloc(dstWidth * dstHeight * sizeof(int));
	
	int currSize = 0;
	int prevSize = 0;
	int newSize = 0;

	int x, y;
	for(y = 0; y < dstHeight; y++)
	{
		for(x = 0; x < dstWidth; x++)
		{
			pixelStackIndex[x + y * dstWidth] = -1;
			vectorMap[x + y * dstWidth].x = 0;
			vectorMap[x + y * dstWidth].y = 0;

			int srcx = x - dstx;
			int srcy = y - dsty;
			if(srcx < 0 || srcx >= srcWidth || srcy < 0 || srcy >= srcHeight) continue;
			
			/*sdmTexData[(x + y * dstWidth) * 4 + 0] = texData[(srcx + srcy * srcWidth) * 4 + 0];
			sdmTexData[(x + y * dstWidth) * 4 + 1] = texData[(srcx + srcy * srcWidth) * 4 + 1];
			sdmTexData[(x + y * dstWidth) * 4 + 2] = texData[(srcx + srcy * srcWidth) * 4 + 2];
			sdmTexData[(x + y * dstWidth) * 4 + 3] = texData[(srcx + srcy * srcWidth) * 4 + 3];*/			
			

			if(texData[(srcx + srcy * srcWidth) * 4 + 3] > 128)
			{
				pixelStackIndex[x + y * dstWidth] = currSize;
				pixelStack[currSize].x = x;
				pixelStack[currSize].y = y;
				currSize++;
			}
		}
	}
	
	int dist = 0;
	bool done = 0;
	while(!done)
	{
		dist++;
		int newSize = currSize;
		int pixelIndex;
		int neighbourNumber;
		for(pixelIndex = prevSize; pixelIndex < currSize; pixelIndex++)
		{
			for(neighbourNumber = 0; neighbourNumber < 8; neighbourNumber++)
			{
				int xoffset = 0;
				int yoffset = 0;
				switch(neighbourNumber)
				{
					case 0: xoffset =  1; yoffset =  0; break;
					case 1: xoffset =  0; yoffset =  1; break;
					case 2: xoffset = -1; yoffset =  0; break;
					case 3: xoffset =  0; yoffset = -1; break;
					case 4: xoffset =  1; yoffset =  1; break;
					case 5: xoffset = -1; yoffset =  1; break;
					case 6: xoffset = -1; yoffset = -1; break;
					case 7: xoffset =  1; yoffset = -1; break;
				}
				if(pixelStack[pixelIndex].x + xoffset >= dstWidth  || pixelStack[pixelIndex].x + xoffset < 0 ||
					 pixelStack[pixelIndex].y + yoffset >= dstHeight || pixelStack[pixelIndex].y + yoffset < 0) continue;

				int currIndex = pixelStack[pixelIndex].x + pixelStack[pixelIndex].y * dstWidth;
				int neighbourIndex = (pixelStack[pixelIndex].x + xoffset) + (pixelStack[pixelIndex].y + yoffset) * dstWidth;
				
				Vector currOffset;
				currOffset.x = vectorMap[currIndex].x + xoffset;
				currOffset.y = vectorMap[currIndex].y + yoffset;
				if(pixelStackIndex[neighbourIndex] == -1)
				{
					vectorMap[neighbourIndex] = currOffset;

					pixelStackIndex[neighbourIndex] = newSize;

					pixelStack[newSize].x = pixelStack[pixelIndex].x + xoffset;
					pixelStack[newSize].y = pixelStack[pixelIndex].y + yoffset;
					newSize++;
				}else
				{
					if(vectorMap[neighbourIndex].x * vectorMap[neighbourIndex].x + vectorMap[neighbourIndex].y * vectorMap[neighbourIndex].y >
						 currOffset.x * currOffset.x + currOffset.y * currOffset.y)
					{
						vectorMap[neighbourIndex] = currOffset;
						/*float weight0 = sqrtf(vectorMap[neighbourIndex].x * vectorMap[neighbourIndex].x + vectorMap[neighbourIndex].y * vectorMap[neighbourIndex].y);
						float weight1 = sqrtf(currOffset.x * currOffset.x + currOffset.y * currOffset.y);
						vectorMap[neighbourIndex].x = vectorMap[neighbourIndex].x * weight1 / (weight0 + weight1) + currOffset.x * weight0 / (weight0 + weight1);
						vectorMap[neighbourIndex].y = vectorMap[neighbourIndex].y * weight1 / (weight0 + weight1) + currOffset.y * weight0 / (weight0 + weight1);*/
					}
				}        
			}
		}
		if(currSize == newSize)
		{
			done = 1;
		}
		prevSize = currSize;
		currSize = newSize;
	}

	for(y = 0; y < dstHeight; y++)
	{
		for(x = 0; x < dstWidth; x++)
		{
			Vector offset = vectorMap[x + y * dstWidth];
			float offsetLen = sqrtf((float)(offset.x * offset.x + offset.y * offset.y));

			Vector currPoint;
			currPoint.x = x;
			currPoint.y = y;


			Vector basePoint;
			basePoint.x = currPoint.x - offset.x*0;
			basePoint.y = currPoint.y - offset.y*0;

			Vector centerPoint;
			centerPoint.x = dstx + srcWidth  / 2;
			centerPoint.y = dsty + srcHeight / 2;
			//float ang = atan2((float)(basePoint.x - centerPoint.x), -(float)(basePoint.y - centerPoint.y)); //0 is at up
			float ang = atan2((float)(basePoint.x - centerPoint.x), (float)(basePoint.y - centerPoint.y));
			//float ang = atan2((float)(offset.x), -(float)(offset.y));
			sdmTexData[(x + y * dstWidth) * 4 + 0] = 127 + (float)(-vectorMap[x + y * dstWidth].x) / maxSize * 127;
			sdmTexData[(x + y * dstWidth) * 4 + 1] = 127 + (float)(-vectorMap[x + y * dstWidth].y) / maxSize * 127;
			sdmTexData[(x + y * dstWidth) * 4 + 2] = 127 + (float)(-vectorMap[x + y * dstWidth].y) / maxSize * 127;
			// sdmTexData[(x + y * dstWidth) * 4 + 2] = (unsigned char)(clamp(ang / 3.141592f * 0.5f + 0.5f, 0.0f, 1.0f) * 255);
			sdmTexData[(x + y * dstWidth) * 4 + 3] = (unsigned char)(offsetLen / sqrtf(dstWidth * dstWidth + dstHeight * dstHeight) * 255);
		}
	}

	/*for(y = 0; y < dstHeight; y++)
	{
		for(x = 0; x < dstWidth; x++)
		{
			int dstPointx = x + (sdmTexData[(x + y * dstWidth) * 4 + 0] / 255.0 - 0.5) * maxSize;
			int dstPointy = y + (sdmTexData[(x + y * dstWidth) * 4 + 1] / 255.0 - 0.5) * maxSize;

			float planarx = sdmTexData[(x + y * dstWidth) * 4 + 2] / 255.0;
			float planary = sdmTexData[(x + y * dstWidth) * 4 + 3] / 255.0;
			
			char resultColor[4];
			GetBackgroundColor(Vector2f(planarx, planary), 0.1f, resultColor);


			for(int componentIndex = 0; componentIndex < 4; componentIndex++)
			{
				sdmTexData[(x + y * dstWidth) * 4 + componentIndex] = resultColor[componentIndex];
			}
		}
	}*/
	free(pixelStack);
	free(vectorMap);
	free(pixelStackIndex);
}
