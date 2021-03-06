/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// Variable.as
// John Maloney, February 2010
//
// A variable is a name-value pair.

package interpreter;


import util.JSON;

class Variable
{

	public var name : String;
	public var value : Dynamic;
	public var watcher : Dynamic;
	public var isPersistent : Bool;

	public function new(vName : String, initialValue : Dynamic)
	{
		name = vName;
		value = initialValue;
	}

	public function writeJSON(json : util.JSON) : Void{
		json.writeKeyValue("name", name);
		json.writeKeyValue("value", value);
		json.writeKeyValue("isPersistent", isPersistent);
	}
}
