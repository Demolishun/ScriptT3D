//-----------------------------------------------------------------------------
// scriptT3D.cpp
// Copyright Demolishun Consulting 2011
//-----------------------------------------------------------------------------

#include "scriptT3D.h"
#include "console/engineAPI.h"

// determine if the string is a valid identifier
bool isValidIdentifier(const char *name){
	int slen;
	
	if(!name)
		return false;
	
	slen = dStrlen(name);

	// first letter must be alpha
	if(!dIsalpha(name[0]))
		return false;
	for(int count=1; count<slen; count++){
		if(!dIsalnum(name[count])){
			if(name[count] == '_')
				continue;
			else
				return false;
		}
	}

	return true;
}

// not null and not empty
bool isNotNullNotEmptyCString(const char *teststr){
	if(!teststr)
		return false;
	if(!dStrlen(teststr))
		return false;
	return true;
}

namespace Con
{
	void addScriptCommand( const char *nsName, const char *name, ScriptStringCallback cb, const char *usage, S32 minArgs, S32 maxArgs, bool isToolOnly, ConsoleFunctionHeader* header )
	{
		Namespace *ns = NULL;
		if(nsName)
			ns = lookupNamespace(nsName);
		else
			ns = Namespace::global();
		ns->addScriptCommand( StringTable->insert(name), cb, usage, minArgs, maxArgs, isToolOnly, header );
	}
};

// new script objects
IMPLEMENT_CONOBJECT(extScriptObject);

// ext script object
extScriptObject::extScriptObject()
{
	/* 
	Without external script object reference this object will just be a normal ScriptObject.
	*/
	mObject = NULL;
}
// clean up
extScriptObject::~extScriptObject()
{
	if(mObject){
		delete mObject;
	}
}

// set the object, and add functions to namespace
void extScriptObject::SetObject(extCallBackObject *obj)
{
	// get ref for external callback object
	mObject = obj;

	// export functions 
	if(mObject)
	{
		mObject->exportFunctions(this);
	}
}

// attribute functions
const char *extScriptObject::getDataField(StringTableEntry slotName, const char *array){
	//char buffer[512];

	const char* ret = NULL;
	
	// when an attribute is set on a SimObject using the ID getDataField gets called
	// this checks for that case as the whole expression is provide in slotName
	// since the expression contains an equal sign it is easy to filter out
	if(dStrchr(slotName,int('='))){
		Con::printf("extScriptObject::getDataField: ignoring corner case");
		return "";  // make sure to return empty string, NULL will cause more processing to occur
	}

	Con::printf("extScriptObject::getDataField('%s','%s')",slotName, array);

	// handle non-sequence attributes
	if(!array || !dStrlen(array)){
		ret = mObject->getAttribute(slotName);
	}
	// detect and handle sequences
	else{
		ret = mObject->getAttribute(slotName,array);
	}

	if(!ret)
		ret = "";

	return ret;
}
void extScriptObject::setDataField(StringTableEntry slotName, const char *array, const char *value){
	Con::printf("extScriptObject::setDataField('%s','%s','%s')",slotName, array, value);

	if(!array || !dStrlen(array)){
		mObject->setAttribute(slotName, value);
	}
	else{
		mObject->setAttribute(slotName,array,value);
	}
}

