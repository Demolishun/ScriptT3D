/*
//-----------------------------------------------------------------------------
// scriptT3D.i
//-----------------------------------------------------------------------------

Copyright (c) 2012 Frank Carney

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:
The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*
SWIG processing in VC++:
- Create an external tool under Tools->External Tools...
- Call the tool SWIG and point to your swig.exe executable for the 'Command'.
- Add the following Arguments: -c++ -python -builtin -threads $(ItemPath)
- Deselect Prompt on Arguments (optional)
- Select Use Output Window (optional)
- Make scriptT3D.i the current document and select the tool from Tools->SWIG
This will build the scriptT3D_wrap.cxx and the scriptT3D.py files.
*/

/*
Custom build step for copying scriptT3D.py to game folder of project.  
This will always copy latest scriptT3D.py file to game directory every time a Build is performed.
Command Line: copy /V/Y "$(InputPath)" "$(TargetDir)"
Desciption: Copying "$(InputPath)" to game directory "$(TargetDir)"
Outputs: "$(InputDir)bogus.txt"
Additional Dependencies:
*/

/*
Callback Exporting:
If is called as a method of a TS object then function will require a 'this' parameter.
*/

/*
Todo:
- Create Python unit tests to ensure features work as intended on each release.
Planned expansion:
- Binary data exchange such as textures, sounds, models, etc
- Parser to convert all the Torque Script to Javascript or Python
*/

%module scriptT3D

%{
#define SWIG_FILE_WITH_INIT
#include "scriptT3Dsimple.h"
%}

// default typemaps
%typemap(in) S32 = int;
%typemap(out) S32 = int;
%typemap(in) U32 = unsigned int;
%typemap(out) U32 = unsigned int;

// include python related SWIG file
#ifdef SWIGPYTHON
%include "pyT3Dsimple.i"
%include "pyT3Dcallbacks.i"
#endif 

%rename("%(strip:[torque_engine])s") "";
// engine startup/shutdown
int torque_engineinit(S32 argc, const char **argv);

// engine loop
int torque_enginetick();

// engine state/events
int torque_engineshutdown();

%rename("%(strip:[torque_])s") "";

// is this a debug build
bool torque_isdebugbuild();
// evaluate arbitrary console code
const char* torque_evaluate(const char* code);
// global variable access
//const char* torque_getvariable(const char* name);
//void torque_setvariable(const char* name, const char* value);

// wrap functions the need type conversion
%{
// hwnd
long gethwnd(){
   return (long)torque_gethwnd();
}
%}
// get window handle
long gethwnd();

%{
// globals
extern ExprEvalState gEvalState;
extern StringStack STR;

// object to hold function calls for methods
class FunctionCaller{
private:
   const char *fname;
   SimObject *sobject;
   Namespace::Entry *ent;
   char idBuf[32];
public:
   FunctionCaller(const char *name);
   FunctionCaller(SimObject *object, const char *name);  
   ~FunctionCaller(); 
   const char *Call(int argc, const char **argv);
   const char *ObjectCall(int argc, const char **argv);   
};
FunctionCaller::FunctionCaller(const char *name){
   sobject = NULL;
   fname = name;
   ent = NULL;
}
FunctionCaller::FunctionCaller(SimObject *object, const char *name){
   sobject = object;
   if(sobject){
      sobject->registerReference(&sobject);
   }
   fname = name;
   ent = NULL;
}
FunctionCaller::~FunctionCaller(){
   if(sobject){
      sobject->unregisterReference(&sobject);
   }
}
const char *FunctionCaller::Call(int argc, const char **argv){
#ifdef TORQUE_MULTITHREAD
   if(Con::isMainThread())
   {
#endif
      //Namespace::Entry *ent;
      if(!ent){
         StringTableEntry funcName = StringTable->insert(fname);
         ent = Namespace::global()->lookup(funcName);
      }

      if(!ent)
      {
         // consider putting exception here
         Con::warnf("FunctionCaller::Call %s: Unknown command.", fname);

         // Clean up arg buffers, if any.
         STR.clearFunctionOffset();
         return "";
      }

      // create targs list including function name
      const char** targs = (const char**)malloc(sizeof(char*)*(argc+1));
      targs[0] = fname;
      memcpy((void*)&targs[1],(void*)&argv[0],sizeof(char*)*(argc));

      // call the function
      const char *result = ent->execute(argc+1, targs, &gEvalState);

      // free the argument list
      free(targs);
      
      // return the result
      return result; 
#ifdef TORQUE_MULTITHREAD
   }
   else
   {
      // some type of exception here
      Con::warnf("FunctionCaller::Call %s: Called outside main thread.", fname);
      return "";
   }
#endif
}
const char *FunctionCaller::ObjectCall(int argc, const char **argv){
   if(!sobject){
      Con::warnf("FunctionCaller::ObjectCall object appears to no longer exist.");
      return "";
   }
      
   if(sobject->getNamespace())
   {        
      if(!ent){
         StringTableEntry funcName = StringTable->insert(fname);
         ent = sobject->getNamespace()->lookup(funcName);

         dSprintf(idBuf, sizeof(idBuf), "%d", sobject->getId());
      }

      if(!ent)
      {
         STR.clearFunctionOffset();
         return "";
      }

      // add 2 more slots to the buffer
      // create targs list including function name
      const char** targs = (const char**)malloc(sizeof(char*)*(argc+2));
      targs[0] = fname;
      targs[1] = NULL;
      memcpy((void*)&targs[2],(void*)&argv[0],sizeof(char*)*(argc));

      // stick object id in args      
      targs[1] = idBuf;

      // call the function
      SimObject *save = gEvalState.thisObject;
      gEvalState.thisObject = sobject;
      const char *ret = ent->execute(argc+2, targs, &gEvalState);
      gEvalState.thisObject = save;

      // free the argument list
      free(targs);

      return ret;
   }
   Con::warnf("FunctionCaller::ObjectCall %d has no namespace: %s", sobject->getId(), fname);
   return "";
} 
// check for object and get ref
SimObject* getSimObject(const char* objectname){
	SimObject *tobj = Sim_FindObjectByString(objectname);
   if(!tobj)
      return NULL;
   return tobj;
}
// check for object and get ref
SimObject* getSimObject(int objectid){
   SimObject *tobj = Sim_FindObjectById(objectid);
   if(!tobj)
      return NULL;
   return tobj;
}
S32 convSimObjectID(const char* param){
	S32 tid;

	if(!param || !dStrlen(param))
		return 0;

	tid = dAtoi(param);
	if(tid > 0)
		return tid;

	return 0;
}
// check validity of function or method
// if nameSpace is NULL it checks against global namespace
bool isFunction(const char* nameSpace, const char* name){
	const char *ns = nameSpace;
	SimObject *tsim;

	// check for sim id
	if(nameSpace && dStrlen(nameSpace)){
		//Con::printf("%s",nameSpace);
		if(convSimObjectID(nameSpace)){
			//Con::printf("%s",nameSpace);
			tsim = getSimObject(nameSpace);
			if(!tsim)
				return false;
			ns = tsim->getClassName();
		}
	}

	if(script_get_namespace_entry(ns, name) != NULL)
		return true;

	return false;
}
// get and set attributes on SimObjects
const char *getSimObjectAttribute(SimObject *object, const char *attribName, const char *index=NULL){
   return object->getDataField(StringTable->insert(attribName), index);
}
void setSimObjectAttribute(SimObject *object, const char *attribName, const char *value, const char *index=NULL){
   object->setDataField(StringTable->insert(attribName), index, value);
}
bool isSimObjectAttribute(SimObject *object, const char* attribname, bool includeStatic = true, bool includeDynamic = true){
   return object->isField(attribname, includeStatic, includeDynamic);
}
bool isSimObjectMethod(SimObject *object, const char* funcname){
   return object->isMethod(funcname);
}
/*
U32 getSimObjectDataFieldType(SimObject *object, const char* attribName, const char* index=NULL){
   return object->getDataFieldType(StringTable->insert(attribName), index);   
}
*/
// get and set globals variables
const char *getVariable(const char *name){
   bool success = false;
   //name = prependDollar(name);
   const char *result = gEvalState.globalVars.getVariable(StringTable->insert(name), &success);
   // return NULL if there is not variable
   if(success == false)
      return NULL;

   return result;
}
void setVariable(const char *name, const char *value){
   torque_setvariable(name, value);
}
%}
class FunctionCaller{
public:
   FunctionCaller(const char *name);
   FunctionCaller(SimObject *object, const char *name);
   const char *Call(int argc, const char **argv);
   const char *ObjectCall(int argc, const char **argv);
};
SimObject* getSimObject(const char* objectname);
SimObject* getSimObject(int objectid);
bool isFunction(const char* nameSpace, const char* name);
const char *getSimObjectAttribute(SimObject *object, const char *attribName, const char *index=NULL);
void setSimObjectAttribute(SimObject *object, const char *attribName, const char *value, const char *index=NULL);
bool isSimObjectAttribute(SimObject *object, const char* attribname, bool includeStatic = true, bool includeDynamic = true);
bool isSimObjectMethod(SimObject *object, const char* funcname);
//U32 getSimObjectDataFieldType(SimObject *object, const char* attribName, const char* index=NULL);
const char *getVariable(const char *name);
void setVariable(const char *name, const char *value);

// getting the TS equivalent of a SimObject
const char* getSimObjectScript(SimObject *obj);
