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

package svgeditor;

import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.IEventDispatcher;
import openfl.filters.GlowFilter;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextFieldType;

import svgeditor.objs.ISVGEditable;
import svgeditor.objs.SVGBitmap;
import svgeditor.objs.SVGGroup;
import svgeditor.objs.SVGShape;
import svgeditor.objs.SVGTextField;

import svgutils.SVGElement;

class Selection implements IEventDispatcher
{
        private var selectedObjects:Array;
        private var refDispObj:DisplayObject;

        public function new(objs:Array) {
                selectedObjects = objs;

                createRefObject();
        }

        private function createRefObject() : Void {
                if(refDispObj != null) {
                        if(refDispObj.parent) refDispObj.parent.removeChild(refDispObj);
                        refDispObj = null;
                }

                var refShape:Sprite = new Sprite();
                refDispObj = refShape;
                selectedObjects[0].parent.addChild(refDispObj);
                var r:Rectangle;
                if(selectedObjects.length == 1) {
                        refShape.rotation = selectedObjects[0].rotation;
                        r = getBounds(refShape);
                } else {
                        // Set the position
                        r = getBounds(selectedObjects[0].parent);
                }
                refShape.x = r.left;
                refShape.y = r.top;
        }

        // TODO: remove the requirement to send the contentLayer
        // Clone all of the selected objects and return an array of them
        public function cloneObjs(contentLayer:Sprite):Array {
                var copiedObjects:Array = null;
                if(!selectedObjects.length) return copiedObjects;

                // Get a copy of the selected objects
                var objsCopy:Array = [];
                for(i in 0...selectedObjects.length) {
                        var dObj : DisplayObject = selectedObjects[i].parent;
                        var m:Matrix = new Matrix();
                        while(dObj != contentLayer) {
                                m.concat(dObj.transform.matrix);
                                dObj = dObj.parent;
                        }

                        var newObj:ISVGEditable = selectedObjects[i].clone();
                        cast(newObj, DisplayObject).transform.matrix.concat(m);
                        newObj.getElement().transform = cast(newObj, DisplayObject).transform.matrix.clone();
                        objsCopy.push(newObj);
                }

                return objsCopy;
        }

        public function shutdown() : Void {
                if(refDispObj.parent) refDispObj.parent.removeChild(refDispObj);
                refDispObj = null;
        }

        public function contains(obj:DisplayObject):Boolean {
                return (selectedObjects.indexOf(obj) != -1);
        }

        // Bring the selected objects forward within their parent
        public function raise(fully:Boolean = false) : Void {
                var p:DisplayObjectContainer = refDispObj.parent;
                var topIndex:Int = p.numChildren - 1;
                if(fully) {
                        for(var i:Int=0; i<selectedObjects.length; ++i)
                                p.setChildIndex(selectedObjects[i], topIndex);
                }
                else {
                        for(i=0; i<selectedObjects.length; ++i) {
                                var idx:Int = getNextIndex(p.getChildIndex(selectedObjects[i]), 1);
                                p.setChildIndex(selectedObjects[i], idx);
                        }
                }
        }

        // Send the selected objects backward within their parent
        public function lower(fully:Boolean = false) : Void {
                var p:DisplayObjectContainer = refDispObj.parent;
                if(fully) {
                        for(var i:Int=0; i<selectedObjects.length; ++i)
                                p.setChildIndex(selectedObjects[i], 0);
                }
                else {
                        for(i=0; i<selectedObjects.length; ++i) {
                                var idx:Int = getNextIndex(p.getChildIndex(selectedObjects[i]), -1);
                                p.setChildIndex(selectedObjects[i], idx);
                        }
                }
        }

        private function getNextIndex(cur:int, dir:int):Int {
                var p:DisplayObjectContainer = refDispObj.parent;
                cur += dir;
                while(cur>0 && cur < p.numChildren && !(p.getChildAt(cur) is ISVGEditable))
                        cur += dir;

                cur = Math.max(0, Math.min(p.numChildren - 1, cur));
                return cur;
        }

        // Remove selected objects
        public function remove() : Void {
                if(selectedObjects.length == 0) return;

                var p:DisplayObjectContainer = selectedObjects[0].parent;
                if(p)
                        for(var i:Int=0; i<selectedObjects.length; ++i)
                                p.removeChild(selectedObjects[i]);
                else
                        trace("Selection contained orphaned objects");

                selectedObjects = [];
        }

        public function group():Selection {
                if(selectedObjects.length > 1) {
                        var p:DisplayObjectContainer = selectedObjects[0].parent;
                        var g:SVGGroup = new SVGGroup(new SVGElement('g', ''));
                        p.addChild(g);

                        // Add the children in the right order
                        for(var i:Int=0; i<p.numChildren; ++i)
                                if(selectedObjects.indexOf(p.getChildAt(i)) != -1) {
                                        g.addChild(p.getChildAt(i));
                                        --i;
                                }

                        return new Selection([g]);
                }

                return this;
        }

        public function ungroup():Selection {
                if(isGroup()) {
                        var m:Matrix = selectedObjects[0].transform.matrix;
                        var g:SVGGroup = selectedObjects[0];
                        var idx:Int = g.parent.getChildIndex(g) + 1;
                        var newSelObjs:Array = [];
                        while(g.numChildren) {
                                // Merge the matrices
                                var gi:Int = g.numChildren - 1;
                                var dObj:DisplayObject = g.getChildAt(gi);
                                var fm:Matrix = dObj.transform.matrix.clone();
                                fm.concat(m);
                                dObj.transform.matrix = fm;
                                newSelObjs.push(dObj);

                                // Put the object at the same level the group was
                                g.parent.addChildAt(dObj,idx);
                        }

                        // Delete the group
                        g.parent.removeChild(g);
                        return new Selection(newSelObjs);
                }

                return this;
        }

        public function isGroup():Boolean {
                return (selectedObjects.length == 1 && selectedObjects[0] is SVGGroup);
        }

        public function isTextField():Boolean {
                return (selectedObjects.length == 1 && selectedObjects[0] is SVGTextField);
        }

        public function canMoveByMouse():Boolean {
                return (!isTextField() || cast(selectedObjects[0], SVGTextField).selectable == false);
        }

        public function isShape():Boolean {
                return (selectedObjects.length == 1 && selectedObjects[0] is SVGShape);
        }

        public function isImage():Boolean {
                return (selectedObjects.length == 1 && selectedObjects[0] is SVGBitmap);
        }

        public function getObjs():Array {
                return selectedObjects;
        }

        public function saveTransform() : Void {
                for(var i:Int=0; i<selectedObjects.length; ++i) {
                        var elem:SVGElement = cast(selectedObjects[i], ISVGEditable).getElement();
                        var m:Matrix = selectedObjects[i].transform.matrix;
                        elem.setAttribute('transform', 'matrix('+m.a+','+m.b+','+m.c+','+m.d+','+m.tx+','+m.ty+')');
                }
        }

        public function getRotation(contentLayer:Sprite):Number {
                if(selectedObjects.length == 1) {
                        var m:Matrix = new Matrix();
                        var dObj:DisplayObject = cast(selectedObjects[0], DisplayObject);
                        while(dObj && (dObj != contentLayer)) {
                                m.concat(dObj.transform.matrix);
                                dObj = dObj.parent;
                        }

                        var s:Sprite = new Sprite();
                        s.transform.matrix = m;
                        return s.rotation;
                }

                return 0;
        }

        private var initialMatrices:Array;
        private var initialTempMatrix:Matrix;
        private var rotationCenter:Point;
        private var origRect:Rectangle;
        private var maintainAspectRatio:Boolean;
        public function startResize(grabLoc:String) : Void {
                saveMatrices();
                origRect = getBounds(refDispObj);
                maintainAspectRatio = (grabLoc != grabLoc.toLowerCase());
        }

        // This can probably be optimized even more
        // The grab location won't change after startResize is called
        public function scaleByMouse(grabLoc:String) : Void {
                var r:Rectangle = origRect;
                var sx:Number = 1.0;
                var sy:Number = 1.0;
                var anchor:String;
                switch(grabLoc) {
                        case 'topLeft':
                                anchor = 'bottomRight';
                                sx = (r.right - refDispObj.mouseX) / r.width;
                                sy = (r.bottom - refDispObj.mouseY) / r.height;
                                break;
                        case 'top':
                                anchor = 'bottomRight';
                                sy = (r.bottom - refDispObj.mouseY) / r.height;
                                break;
                        case 'topRight':
                                anchor = 'bottomLeft';
                                sx = (refDispObj.mouseX - r.left) / r.width;
                                sy = (r.bottom - refDispObj.mouseY) / r.height;
                                break;
                        case 'right':
                                anchor = 'topLeft';
                                sx = (refDispObj.mouseX - r.left) / r.width;
                                break;
                        case 'bottomLeft':
                                anchor = 'topRight';
                                sx = (r.right - refDispObj.mouseX) / r.width;
                                sy = (refDispObj.mouseY - r.top) / r.height;
                                break;
                        case 'bottom':
                                anchor = 'topLeft';
                                sy = (refDispObj.mouseY - r.top) / r.height;
                                break;
                        case 'bottomRight':
                                anchor = 'topLeft';
                                sx = (refDispObj.mouseX - r.left) / r.width;
                                sy = (refDispObj.mouseY - r.top) / r.height;
                                break;
                        case 'left':
                                anchor = 'bottomRight';
                                sx = (r.right - refDispObj.mouseX) / r.width;
                                break;
                }

                var anchorPt:Point;
                switch(anchor) {
                        case 'topLeft':
                        case 'bottomRight':
                                anchorPt = r[anchor];
                                break;
                        case 'topRight':
                                anchorPt = new Point(r.right, r.top);
                                break;
                        case 'bottomLeft':
                                anchorPt = new Point(r.left, r.bottom);
                                break;
                }
                anchorPt = refDispObj.parent.globalToLocal(refDispObj.localToGlobal(anchorPt));

                // Maintain aspect ratio if we're resizing a shape and
                if(maintainAspectRatio) {
                        sx = sy = Math.min(sx, sy);
                }

                // Don't flip the object
                //sx = Math.max(sx, 0);
                //sy = Math.max(sy, 0);

                for(var i:Int=0; i<selectedObjects.length; ++i) {
                        var obj:DisplayObject = selectedObjects[i];
                        scaleAroundPoint(obj, anchorPt.x, anchorPt.y, sx, sy, initialMatrices[i].clone());
                }
        }

        private function scaleAroundPoint(objToScale:DisplayObject, regX:int, regY:int, scaleX:Number, scaleY:Number, m:Matrix) : Void{
                var r:Number = refDispObj.rotation * Math.PI / 180;
                m.translate( -regX, -regY );
                m.rotate(-r);
                m.scale(scaleX, scaleY);
                m.rotate(r);
                m.translate( regX, regY );
                objToScale.transform.matrix = m;
        }

        public function flip(vertical:Boolean = false) : Void {
                var r:Rectangle = getBounds(refDispObj.parent);
                var anchorPt:Point = new Point((r.left+r.right)/2, (r.top+r.bottom)/2);

                for(var i:Int=0; i<selectedObjects.length; ++i) {
                        var obj:DisplayObject = selectedObjects[i];
                        flipAroundPoint(obj, anchorPt.x, anchorPt.y, vertical);
                }
        }

        // TODO: Make more robust for flipping over and over (don't use the concatonated matrix, keep the transforms within the parent)
        private function flipAroundPoint(objToFlip:DisplayObject, regX:Number, regY:Number, vertical:Boolean) : Void{
                var p:Point = objToFlip.parent.localToGlobal(new Point(regX, regY));
                var m2:Matrix = objToFlip.transform.concatenatedMatrix.clone();
                m2.translate(-p.x, -p.y);
                m2.scale(vertical ? 1 : -1, vertical ? -1 : 1);
                m2.translate(p.x, p.y);
                var m3:Matrix = objToFlip.parent.transform.concatenatedMatrix.clone();
                m3.invert();
                m2.concat(m3);

                objToFlip.transform.matrix = m2;
        }

        public function startRotation(center:Point) : Void {
                rotationCenter = refDispObj.parent.globalToLocal(center);
                saveMatrices();

                initialTempMatrix = refDispObj.transform.matrix.clone();
        }

        private function saveMatrices() : Void {
                initialMatrices = new Array();
                for(var i:Int=0; i<selectedObjects.length; ++i)
                        initialMatrices.push(selectedObjects[i].transform.matrix.clone());
        }

        // TODO: Move this into the SVGElement class
        public function setShapeProperties(props:DrawProperties) : Void {
                for(var i:Int=0; i<selectedObjects.length; ++i) {
                        var el:SVGElement = selectedObjects[i].getElement();
                        el.applyShapeProps(props);
                        selectedObjects[i].redraw();
                }
        }

        public function doRotation(angle:Number) : Void {
                var c:Point = rotationCenter;
                for(var i:Int=0; i<selectedObjects.length; ++i) {
                        var m:Matrix = initialMatrices[i].clone();
                        m.translate(-c.x, -c.y);
                        m.rotate( angle );
                        m.translate(c.x, c.y);
                        selectedObjects[i].transform.matrix = m;
                }

                m = initialTempMatrix.clone();
                m.translate(-c.x, -c.y);
                m.rotate( angle );
                m.translate(c.x, c.y);
                refDispObj.transform.matrix = m;
        }

        public function getGlobalBoundingPoints():Object {
                var r:Rectangle = getBounds(refDispObj);

                return {
                        topLeft:	refDispObj.localToGlobal(r.topLeft),
                        topRight:	refDispObj.localToGlobal(new Point(r.right, r.top)),
                        botLeft:	refDispObj.localToGlobal(new Point(r.left, r.bottom)),
                        botRight:	refDispObj.localToGlobal(r.bottomRight)
                };
        }

        public function setTLPosition(p:Point) : Void {
                var parentSpaceTL:Point = refDispObj.parent.globalToLocal(p);
                var globalCurrentTL:Point = refDispObj.localToGlobal(getBounds(refDispObj).topLeft);
                var offset:Point = parentSpaceTL.subtract(refDispObj.parent.globalToLocal(globalCurrentTL));
//trace('offset: '+offset);

                for(var i:Int=0; i<selectedObjects.length; ++i) {
                        var obj:DisplayObject = selectedObjects[i];
                        obj.x += offset.x;
                        obj.y += offset.y;
                        var p2:Point = new Point(obj.x, obj.y);
//trace(obj+': '+p2);
                }

                refDispObj.x += offset.x;
                refDispObj.y += offset.y;
        }

        // Get a rectangle surrounding the entire set of select objects
        public function getBounds(ctx:DisplayObject):Rectangle {
                var bounds:Rectangle = selectedObjects[0].getBounds(ctx);
                if(selectedObjects.length > 1) {
                        for(var i:Int = 1; i<selectedObjects.length; ++i) {
                                bounds = bounds.union(selectedObjects[i].getBounds(ctx));
                        }
                }

                return bounds;
        }

        public function toggleHighlight(on:Boolean) : Void {
                return;
                var filters:Array = on ? [new GlowFilter(0x28A5DA)] : [];
                for(var i:Int=0; i<selectedObjects.length; ++i)
                        cast(selectedObjects[i], DisplayObject).filters = filters;
        }

        // Below is the EventDispatcher interface implementation
        public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false) : Void {
                for(var i:Int=0; i<selectedObjects.length; ++i)
                        selectedObjects[i].addEventListener(type, listener, useCapture, priority, useWeakReference);
        }

        public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false) : Void {
                for(var i:Int=0; i<selectedObjects.length; ++i)
                        selectedObjects[i].removeEventListener(type, listener, useCapture);
        }

        public function dispatchEvent(event:Event):Boolean {
                var stopProp:Boolean = false;
                for(var i:Int=0; i<selectedObjects.length; ++i)
                        if(selectedObjects[i].dispatchEvent(event))
                                stopProp = true;

                return stopProp;
        }

        public function hasEventListener(type:String):Boolean {
                return selectedObjects[0].hasEventListener(type);
        }

        public function willTrigger(type:String):Boolean {
                return selectedObjects[0].willTrigger(type);
        }
}
}

