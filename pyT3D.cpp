//-----------------------------------------------------------------------------
// pyT3D.cpp
// Copyright Demolishun Consulting 2011
//-----------------------------------------------------------------------------

#include "pyT3D.h"
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

// reference of field access
/*
void SimObject::setDataField(StringTableEntry slotName, const char *array, const char *value)
{
   // first search the static fields if enabled
   if(mFlags.test(ModStaticFields))
   {
      const AbstractClassRep::Field *fld = findField(slotName);
      if(fld)
      {
         // Skip the special field types as they are not data.
         if ( fld->type >= AbstractClassRep::ARCFirstCustomField )
            return;

         S32 array1 = array ? dAtoi(array) : 0;

         if(array1 >= 0 && array1 < fld->elementCount && fld->elementCount >= 1)
         {
            // If the set data notify callback returns true, then go ahead and
            // set the data, otherwise, assume the set notify callback has either
            // already set the data, or has deemed that the data should not
            // be set at all.
            FrameTemp<char> buffer(2048);
            FrameTemp<char> bufferSecure(2048); // This buffer is used to make a copy of the data
            // so that if the prep functions or any other functions use the string stack, the data
            // is not corrupted.

            ConsoleBaseType *cbt = ConsoleBaseType::getType( fld->type );
            AssertFatal( cbt != NULL, "Could not resolve Type Id." );

            const char* szBuffer = cbt->prepData( value, buffer, 2048 );
            dMemset( bufferSecure, 0, 2048 );
            dMemcpy( bufferSecure, szBuffer, dStrlen( szBuffer ) );

            if( (*fld->setDataFn)( this, array, bufferSecure ) )
               Con::setData(fld->type, (void *) (((const char *)this) + fld->offset), array1, 1, &value, fld->table);

            if(fld->validator)
               fld->validator->validateType(this, (void *) (((const char *)this) + fld->offset));

            onStaticModified( slotName, value );

            return;
         }

         if(fld->validator)
            fld->validator->validateType(this, (void *) (((const char *)this) + fld->offset));

         onStaticModified( slotName, value );
         return;
      }
   }

   if(mFlags.test(ModDynamicFields))
   {
      if(!mFieldDictionary)
         mFieldDictionary = new SimFieldDictionary;

      if(!array)
      {
         mFieldDictionary->setFieldValue(slotName, value);
         onDynamicModified( slotName, value );
      }
      else
      {
         char buf[256];
         dStrcpy(buf, slotName);
         dStrcat(buf, array);
         StringTableEntry permanentSlotName = StringTable->insert(buf);
         mFieldDictionary->setFieldValue(permanentSlotName, value);
         onDynamicModified( permanentSlotName, value );
      }
   }
}

//-----------------------------------------------------------------------------

const char *SimObject::getDataField(StringTableEntry slotName, const char *array)
{
   if(mFlags.test(ModStaticFields))
   {
      S32 array1 = array ? dAtoi(array) : -1;
      const AbstractClassRep::Field *fld = findField(slotName);

      if(fld)
      {
         if(array1 == -1 && fld->elementCount == 1)
            return (*fld->getDataFn)( this, Con::getData(fld->type, (void *) (((const char *)this) + fld->offset), 0, fld->table, fld->flag) );
         if(array1 >= 0 && array1 < fld->elementCount)
            return (*fld->getDataFn)( this, Con::getData(fld->type, (void *) (((const char *)this) + fld->offset), array1, fld->table, fld->flag) );// + typeSizes[fld.type] * array1));
         return "";
      }
   }

   if(mFlags.test(ModDynamicFields))
   {
      if(!mFieldDictionary)
         return "";

      if(!array)
      {
         if (const char* val = mFieldDictionary->getFieldValue(slotName))
            return val;
      }
      else
      {
         static char buf[256];
         dStrcpy(buf, slotName);
         dStrcat(buf, array);
         if (const char* val = mFieldDictionary->getFieldValue(StringTable->insert(buf)))
            return val;
      }
   }

   return "";
}
*/

/*
IMPLEMENT_CALLBACK( extScriptObject, onAdd, void, ( SimObjectId ID ), ( ID ),
	"Called when this extScriptObject is added to the system.\n"
	"@param ID Unique object ID assigned when created (%this in script).\n"
);

bool extScriptObject::onAdd()
{
   if (!Parent::onAdd())
      return false;

   // tell namespace about this object
   // this allows access to the extScriptCBObject through the extScriptObject
   mNameSpace->SetScriptObject(this);

   return true;
}
*/

/*
// test code to save what did not work
// torque callback, handles console call
static const char * pyScriptCallback(SimObject *obj, S32 argc, const char **argv){
	// protect the GIL
	PyGILState_STATE gstate;
	gstate = PyGILState_Ensure();

	PyObject *pyobj;
	struct MarshalNativeEntry *nEntry = NULL;
	
	// backtrace test
	const char* btargv[] = {"backtrace"};
    const char* result = Con::execute(1, btargv);
    // try backtrace directly
    if(true)
    {
	   U32 totalSize = 1;
	   
	   Con::printf("btdepth: %d",gEvalState.getStackDepth());

	   for(U32 i = 0; i < gEvalState.getStackDepth(); i++)
	   {
		  if(gEvalState.stack[i]->scopeNamespace && gEvalState.stack[i]->scopeNamespace->mEntryList->mPackage)  
			 totalSize += dStrlen(gEvalState.stack[i]->scopeNamespace->mEntryList->mPackage) + 2;  
		  if(gEvalState.stack[i]->scopeName)  
		  totalSize += dStrlen(gEvalState.stack[i]->scopeName) + 3;
		  if(gEvalState.stack[i]->scopeNamespace && gEvalState.stack[i]->scopeNamespace->mName)
			 totalSize += dStrlen(gEvalState.stack[i]->scopeNamespace->mName) + 2;
	   }

	   char *buf = Con::getReturnBuffer(totalSize);
	   buf[0] = 0;
	   for(U32 i = 0; i < gEvalState.getStackDepth(); i++)
	   {
		  dStrcat(buf, "->");
	      
		  if(gEvalState.stack[i]->scopeNamespace && gEvalState.stack[i]->scopeNamespace->mEntryList->mPackage)  
		  {  
			 dStrcat(buf, "[");  
			 dStrcat(buf, gEvalState.stack[i]->scopeNamespace->mEntryList->mPackage);  
			 dStrcat(buf, "]");  
		  }  
		  if(gEvalState.stack[i]->scopeNamespace && gEvalState.stack[i]->scopeNamespace->mName)
		  {
			 dStrcat(buf, gEvalState.stack[i]->scopeNamespace->mName);
			 dStrcat(buf, "::");
		  }
		  if(gEvalState.stack[i]->scopeName)  
			 dStrcat(buf, gEvalState.stack[i]->scopeName);
	   }

	   Con::printf("BackTrace: %s", buf);
	}
	
	if(gEvalState.getStackDepth()){
		Con::printf("scope: %s",gEvalState.stack[0]->scopeName);
		Namespace *tempNS = gEvalState.stack[0]->scopeNamespace;
		if(tempNS)
			Con::printf("namespace: %s",tempNS->mName);
	}
	
	
	if(obj){
		Con::printf("Function called against object: %s::%s",obj->getName(), argv[0]);
		nEntry = script_get_namespace_entry(obj->getName(), argv[0]);
		if(!nEntry)
			Con::printf("Could not find %s::%s in lookup.", obj->getName(), argv[0]);
	}
	if(!nEntry){
		// determine if first parameter is an object
		obj = Sim_FindObjectByString(argv[1]);
		if(obj){
			Con::printf("Function called with first parameter as a simobject %s::%s.", obj->getName(), argv[0]);
			nEntry = script_get_namespace_entry(obj->getName(), argv[0]);
			if(!nEntry)
				Con::printf("SimObject (%s namespace) does not have the correct namespace for this function %s.", obj->getName(), argv[0]);
		}
	}
	if(!nEntry){
		Con::printf("Function called in global namespace: %s", argv[0]);
		nEntry = script_get_namespace_entry(NULL, argv[0]);
		if(!nEntry)
			Con::printf("Could not find %s in lookup.", argv[0]);
	}
	if(!nEntry){
		// current namespace?
		//nEntry = script_get_namespace_entry(Namespace::getName(), argv[0]);
		//if(!nEntry)
		//	Con::printf("Could not find %s in lookup.", argv[0]);
	}
	if(!nEntry){
		Con::errorf("pyScriptCallback cannot determine namespace for this function.");
	}
	
	
	// convert simobject to python object
	pyobj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), SWIGTYPE_p_SimObject, 0 |  0 );
	
	// protect the GIL
	PyGILState_Release(gstate);
	
	return "Okay";
}
*/