#ifndef __GL21_CHECKER_HPP
#define __GL21_CHECKER_HPP

bool _CheckGL_Error(const char* GLcall, const char* file, const int line)
{
    GLenum errCode;
    if((errCode = glGetError())!=GL_NO_ERROR)
    {
		printf("OPENGL ERROR #%i: (%s) in file %s on line %i\n",errCode,gluErrorString(errCode), file, line);
        printf("OPENGL Call: %s\n",GLcall);
        return false;
    }
    return true;
}

bool _CheckGLSLShaderCompile(GLuint shader, const char* file)
{
	int success;
	int infologLength = 0;
	int charsWritten = 0;
    char *infoLog;

	glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
	glGetShaderiv(shader, GL_INFO_LOG_LENGTH,&infologLength);
	if(infologLength>0)
	{
	    infoLog = (char *)malloc(infologLength);
	    glGetShaderInfoLog(shader, infologLength, &charsWritten, infoLog);
	}
	if(success!=GL_TRUE)
	{
	    // something went wrong
	    printf("GLSL ERROR: Compile error in shader %s\n", file);
		printf("%s\n",infoLog);
		free(infoLog);
		return false;
	}
#ifdef _SHADERVERBOSE
	if(infologLength>1)
	{
	    // nothing went wrong, just warnings or messages
	    printf("GLSL WARNING: Compile log for shader %s\n", file);
	    printf("%s\n",infoLog);
	}
#endif
	if(infologLength>0)
	{
	    free(infoLog);
	}
	return true;
}

bool _CheckGLSLProgramLink(GLuint program)
{
	int success;
	glGetProgramiv(program, GL_LINK_STATUS, &success);
	if(success!=GL_TRUE)
	{
		// Something went Wrong
		int infologLength = 0;
		int charsWritten = 0;
		char *infoLog;
		glGetProgramiv(program, GL_INFO_LOG_LENGTH,&infologLength);
		if (infologLength > 0)
	    {
	        infoLog = (char *)malloc(infologLength);
	        glGetProgramInfoLog(program, infologLength, &charsWritten, infoLog);
			printf("OPENGL ERROR: Program link Error");
			printf("%s\n",infoLog);
	        free(infoLog);
	    }
		return false;
	}
	return true;
}

bool _CheckGLSLProgramValid(GLuint program)
{
	int success;
	glGetProgramiv(program, GL_VALIDATE_STATUS, &success);
	if(success!=GL_TRUE)
	{
		// Something went Wrong
		int infologLength = 0;
		int charsWritten = 0;
		char *infoLog;
		glGetProgramiv(program, GL_INFO_LOG_LENGTH,&infologLength);
		if (infologLength > 0)
	    {
	        infoLog = (char *)malloc(infologLength);
	        glGetProgramInfoLog(program, infologLength, &charsWritten, infoLog);
			printf("OPENGL ERROR: Program Validation Failure");
			printf("%s\n",infoLog);
	        free(infoLog);
	    }
		return false;
	}
	return true;
}

#define _DEBUG
#ifdef _DEBUG

#define CHECKGL( GLcall )                               		\
    GLcall;                                             		\
    if(!_CheckGL_Error( #GLcall, __FILE__, __LINE__))     		\
    exit(-1);

#else

#define CHECKGL( GLcall)        \
    GLcall;
#endif

#define CHECKGLSLCOMPILE( Shader, file )						\
	_CheckGLSLShaderCompile( Shader , file);

#define CHECKGLSLLINK( Program )								\
	_CheckGLSLProgramLink( Program );

#define CHECKGLSLVALID( Program )								\
	glValidateProgram( Program );								\
	_CheckGLSLProgramValid( Program );



#endif
