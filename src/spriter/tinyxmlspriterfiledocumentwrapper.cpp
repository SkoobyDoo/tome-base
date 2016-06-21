extern "C" {
#include "physfs.h"
}
#include "spriter/tinyxmlspriterfiledocumentwrapper.h"
#include "spriter/tinyxmlspriterfileelementwrapper.h"
#include "spriterengine/global/settings.h"

namespace SpriterEngine
{
	TinyXmlSpriterFileDocumentWrapper::TinyXmlSpriterFileDocumentWrapper()
	{
	}

	void TinyXmlSpriterFileDocumentWrapper::loadFile(std::string fileName)
	{
		if (!PHYSFS_exists(fileName.c_str())) {
			Settings::error("TE4SPriter load, file not found: " + fileName);
			return;
		}
		PHYSFS_file *f = PHYSFS_openRead(fileName.c_str());
		size_t len = PHYSFS_fileLength(f);
		if (len < 1) {
			Settings::error("TE4SPriter load, file has -1 size: " + fileName);
			PHYSFS_close(f);
			return;
		}
		char *data = (char*)malloc(len);
		size_t pos = 0;
		while (pos < len) {
			size_t read = PHYSFS_read(f, data + pos, 1, len - pos);
			if (read == 0) break;
			if (read > 0) pos += read;
		}
		doc.Parse(data);
		free((void*)data);
		PHYSFS_close(f);
	}

	SpriterFileElementWrapper * TinyXmlSpriterFileDocumentWrapper::newElementWrapperFromFirstElement()
	{
		return new TinyXmlSpriterFileElementWrapper(doc.FirstChildElement());
	}

	SpriterFileElementWrapper * TinyXmlSpriterFileDocumentWrapper::newElementWrapperFromFirstElement(const std::string & elementName)
	{
		return new TinyXmlSpriterFileElementWrapper(doc.FirstChildElement(elementName.c_str()));
	}

}