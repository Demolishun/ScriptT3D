//-----------------------------------------------------------------------------
// Torque
// Copyright GarageGames, LLC 2011
//-----------------------------------------------------------------------------

#ifndef _SCRIPTOBJECTS_H_
#define _SCRIPTOBJECTS_H_

#ifndef _CONSOLEINTERNAL_H_
#include "console/consoleInternal.h"
#endif

//-----------------------------------------------------------------------------
// Script object placeholder
//-----------------------------------------------------------------------------

class ScriptObject : public SimObject
{
   typedef SimObject Parent;

public:
   ScriptObject();
   // scriptT3D : made virtual
   virtual bool onAdd();
   void onRemove();

   DECLARE_CONOBJECT(ScriptObject);

   DECLARE_CALLBACK(void, onAdd, (SimObjectId ID) );
   DECLARE_CALLBACK(void, onRemove, (SimObjectId ID));
};

#endif