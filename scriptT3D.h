//-----------------------------------------------------------------------------
// scriptT3D.h
// Copyright Demolishun Consulting 2011
//-----------------------------------------------------------------------------

#include "platform/platform.h"
#include "console/compiler.h"
#include "console/consoleInternal.h"
#include "core/util/tDictionary.h"
#include "core/strings/stringFunctions.h"
#include "app/mainLoop.h"
#include "windowManager/platformWindow.h"
#include "windowManager/platformWindowMgr.h"
#include "console/console.h"
#include "console/consoleInternal.h"
#include "console/sim.h"
#include "console/scriptObjects.h"

#ifdef TORQUE_OS_WIN32
#include "windowManager/win32/win32Window.h"
#include "windowManager/win32/winDispatch.h"
extern void createFontInit(void);
extern void createFontShutdown(void);   
#endif

#if defined( TORQUE_MINIDUMP ) && defined( TORQUE_RELEASE )
   extern INT CreateMiniDump(LPEXCEPTION_POINTERS ExceptionInfo);
#endif

#ifdef TORQUE_OS_WIN32
#include "windowManager/win32/win32Window.h"
#include "windowManager/win32/winDispatch.h"
extern void createFontInit(void);
extern void createFontShutdown(void);   
#endif

#ifdef TORQUE_OS_MAC
#endif 

#ifndef _scriptT3D_h
#define _scriptT3D_h


// reference functions
extern "C" {
	struct MarshalNativeEntry
	{
		const char* nameSpace;
		const char* name;
		Namespace::Entry* entry; 
		S32 minArgs;
		S32 maxArgs;
		S32 cbType;
	};

	// engine startup/shutdown
	int torque_engineinit(S32 argc, const char **argv);
	void torque_enginesignalshutdown();

	// engine loop
	int torque_enginetick();

	// engine state/events
	int torque_engineshutdown();
	void torque_reset();

	// util
	bool torque_isdebugbuild();
	const char* torque_getexecutablepath();
	void torque_setexecutablepath(const char* directory);
	void torque_resizewindow(S32 width, S32 height);
	void torque_setwebdeployment(); 

	// console
	const char* torque_evaluate(const char* code);
	const char* torque_getvariable(const char* name);
	void torque_setvariable(const char* name, const char* value);
	void torque_exportstringcallback(StringCallback cb, const char *nameSpace, const char *funcName, const char* usage,  S32 minArgs, S32 maxArgs);
	const char * torque_callscriptfunction(const char* nameSpace, const char* name, S32 argc, const char ** argv);
	const char* torque_callsecurefunction(const char* nameSpace, const char* name, S32 argc, const char ** argv);
	void torque_addsecurefunction(const char* nameSpace, const char* fname);
	const char * script_getconsolexml();

	// platform specific
	void* torque_gethwnd();
	void torque_directmessage(U32 message, U32 wparam, U32 lparam);

	// vars
	const char* torque_getvariable(const char* name);
	void torque_setvariable(const char* name, const char* value);

	// sim
	SimObject * Sim_FindObjectById(S32 param);
	SimObject * Sim_FindObjectByString(const char *param);

	const char * torque_callstringfunction(const char* nameSpace, const char* name, S32 argc, const char ** argv);

	// callbacks
	struct MarshalNativeEntry;
	MarshalNativeEntry* script_get_namespace_entry(const char* nameSpace, const char* name);
	void script_export_callback_string(StringCallback cb, const char *nameSpace, const char *funcName, const char* usage,  S32 minArgs, S32 maxArgs);
}

// sim
class SimSpace {
private:
	S32 convSimObjectID(const char* param){
		S32 tid;

		if(!param || !dStrlen(param))
			return 0;

		tid = dAtoi(param);
		if(tid > 0)
			return tid;

		return 0;
	}
	SimObject* getSimObject(const char* param){
		SimObject *tsim;
		S32 tid;

		if(!param || !dStrlen(param))
			return NULL;

		// check for id lookup
		tid = convSimObjectID(param);
		if(tid){
			//tsim = Sim_FindObjectById(tid);
			tsim = Sim::findObject(tid);
			return tsim;
		}

		// check for name based lookup
		//tsim = Sim_FindObjectByString(param);
		tsim = Sim::findObject(param);

		return tsim;
	}

	bool executeFailed;

public:
	// singleton
	// bad problems, don't try this for now
	/*
	static SimSpace& getInstance()
	{
		static SimSpace instance;	// Guaranteed to be destroyed.
									// Instantiated on first use.

		return instance;
	}
	*/

	SimSpace(){executeFailed = false;};
	
public:
	SimObject* FindObject(S32 param){
		if(param <= 0)
			return NULL;
		//return Sim_FindObjectById(param);
		return Sim::findObject(param);
	}
	SimObject* FindObject(const char* param){
		if(!param || !dStrlen(param))
			return NULL;
		return getSimObject(param);
	}
	const char* GetVariable(const char* name){
		if(!name || !dStrlen(name))
			return NULL;
		//return torque_getvariable(name);
		return Con::getVariable(StringTable->insert(name));
	}
	bool SetVariable(const char* name, const char* value){
		if(!name || !dStrlen(name))
			return false;
		torque_setvariable(name, value);
		const char* tvalue = GetVariable(name);
		if(dStrcmp(value,tvalue) == 0)
			return true;
		else
			return false;
	}
	bool IsFunction(const char* nameSpace, const char* name){
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
	const char* Evaluate(const char* code){
		//return torque_evaluate(code);
		return Con::evaluate(code);
	}
	const char* Execute(const char* simobj, S32 argc, const char** argv){
		SimObject *tsim;

		executeFailed = false;
		
		if(simobj && dStrlen(simobj)){
			tsim = getSimObject(simobj);
			if(!tsim){
				executeFailed = true;
				return NULL;
			}
			return Con::execute(tsim, argc, argv);
		} 
			
		return Con::execute(argc, argv);
	}
	bool ExecuteFailed(){
		return executeFailed;
	}
};

static HashTable<Namespace::Entry*,void*> gScriptCallbackLookup;

bool isValidIdentifier(const char *name);
bool isNotNullNotEmptyCString(const char *teststr);

// add functions to the Con namespace
namespace Con
{
	// function for adding external script commands
	void addScriptCommand( const char *nameSpace, const char* name, ScriptStringCallback cb, const char* usage, S32 minArgs, S32 maxArgs, bool toolOnly = false, ConsoleFunctionHeader* header = NULL );

};

// storage for function object pointers

// ref
class extScriptObject;

// baseclass for callback object
class extCallBackObject
{
protected:
	// object storage
	void *cbObject;

public:
	extCallBackObject(void *object){cbObject = object;}
	~extCallBackObject(){}

	// lookup functions
	void *getObject(){return cbObject;}
	
// functions to be overriden by new class
	// lookup
	virtual bool hasMethod(const char *name)=0;
	// export
	virtual void exportFunctions(extScriptObject *extsobject)=0;

	// attribute functions
	virtual bool hasAttribute(const char *name)=0;
	virtual const char* getAttribute(const char *name)=0;
	virtual const char* getAttribute(const char *name, const char *index)=0;
	virtual void setAttribute(const char *name, const char *value)=0;
	virtual void setAttribute(const char *name, const char *index, const char *value)=0;
};

// add new sim object type for ext script objects
class extScriptObject : public ScriptObject
{
   typedef ScriptObject Parent;

private:
	extCallBackObject *mObject;  // pointer to hold ref to object	

public:
   extScriptObject();
   ~extScriptObject();
   
   DECLARE_CONOBJECT(extScriptObject);

   // object functions
   void SetObject(extCallBackObject *obj);
   extCallBackObject* GetObject(){return(mObject);}

   // attribute functions
   const char *getDataField(StringTableEntry slotName, const char *array);
   void setDataField(StringTableEntry slotName, const char *array, const char *value);
};


// End of file.
#endif