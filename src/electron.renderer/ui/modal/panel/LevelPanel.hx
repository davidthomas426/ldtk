package ui.modal.panel;

class LevelPanel extends ui.modal.Panel {
	var level: data.Level;
	var link : h2d.Graphics;

	public function new() {
		super();

		jMask.hide();
		level = editor.curLevel;
		loadTemplate("levelPanel");

		link = new h2d.Graphics();
		editor.root.add(link, Const.DP_UI);

		// Delete button
		jContent.find("button.delete").click( (_)->{
			if( project.levels.length<=1 ) {
				N.error( L.t._("You can't remove last level.") );
				return;
			}

			new ui.modal.dialog.Confirm(
				Lang.t._("Are you sure you want to delete this level?"),
				true,
				()->{
					var closest = project.getClosestLevelFrom(level);
					new LastChance('Level ${level.identifier} removed', project);
					var l = level;
					project.removeLevel(level);
					editor.ge.emit( LevelRemoved(l) );
					editor.selectLevel( closest );
					editor.camera.scrollToLevel(editor.curLevel);
				}
			);
		});

		// Create button
		jContent.find("button.create").click( (ev:js.jquery.Event)->{
			if( editor.worldTool.isInAddMode() ) {
				editor.worldTool.stopAddMode();
				ev.getThis().removeClass("running");
			}
			else {
				editor.worldTool.startAddMode();
				ev.getThis().addClass("running");
				N.msg(L.t._("Select a spot on the world map..."));
			}
		});

		// Duplicate button
		jContent.find("button.duplicate").click( (_)->{
			var copy = project.duplicateLevel(level);
			editor.selectLevel(copy);
			switch project.worldLayout {
				case Free, GridVania:
					copy.worldX += project.defaultGridSize*4;
					copy.worldY += project.defaultGridSize*4;

				case LinearHorizontal:
				case LinearVertical:
			}
			editor.ge.emit( LevelAdded(copy) );
		});

		jContent.find("button.worldSettings").click( (_)->{
			new ui.modal.panel.WorldPanel();
		});

		updateLevelForm();
		renderLink();
	}

	function renderLink() {
		if( project.worldLayout==LinearHorizontal )
			return;

		var c = 0xffcc00;
		// jWindow.css("border-color", C.intToHex(c));
		var cam = Editor.ME.camera;
		var render = Editor.ME.levelRender;
		link.clear();
		link.lineStyle(2*cam.pixelRatio, c, 0.5);
		var coords = Coords.fromWorldCoords(curLevel.worldX, curLevel.worldCenterY);
		link.moveTo(coords.canvasX, coords.canvasY);
		link.lineTo(0, cam.height*0.5);
	}

	override function onDispose() {
		super.onDispose();
		link.remove();
		link = null;
	}

	override function onClose() {
		super.onClose();
		link.visible = false;
		var anyWorldPanel = false;
		for(m in Modal.ALL)
			if( !m.destroyed && m!=this && Std.isOfType(m,WorldPanel) ) {
				anyWorldPanel = true;
				break;
			}
		if( !anyWorldPanel )
			editor.setWorldMode(false);
	}

	function useLevel(l:data.Level) {
		level = l;
		updateLevelForm();
	}

	override function onGlobalEvent(ge:GlobalEvent) {
		super.onGlobalEvent(ge);

		switch ge {
			case WorldSettingsChanged:
				if( level==null || project.getLevel(level.uid)==null )
					destroy();
				else
					updateLevelForm();

			case ProjectSelected:
				useLevel(editor.curLevel);

			case LevelRestoredFromHistory(l):
				if( l.uid==level.uid )
					useLevel(l);

			case LevelSettingsChanged(l):
				if( l==level )
					updateLevelForm();

			case LevelAdded(level):

			case LevelSelected(l):
				useLevel(l);
				renderLink();

			case LevelRemoved(l):

			case WorldLevelMoved:
				updateLevelForm();
				renderLink();

			case ViewportChanged :
				renderLink();

			case _:
		}
	}

	function onFieldChange() {
		editor.ge.emit( LevelSettingsChanged(level) );
	}

	function onLevelResized(newPxWid:Int,newPxHei:Int) {
		new LastChance( Lang.t._("Level resized"), project );
		var before = level.toJson();
		curLevel.applyNewBounds(0, 0, newPxWid, newPxHei);
		onFieldChange();
		editor.ge.emit( LevelResized(level) );
		editor.curLevelHistory.saveResizedState( before, level.toJson() );
		new J("ul#levelForm *:focus").blur();
	}


	function updateLevelForm() {
		if( level==null ) {
			close();
			return;
		}

		var jForm = jContent.find("ul#levelForm");
		jForm.find("*").off();


		// Level identifier
		jContent.find(".levelIdentifier").text('"${level.identifier}"');
		var i = Input.linkToHtmlInput( level.identifier, jForm.find("#identifier"));
		i.onChange = ()->onFieldChange();

		// Coords
		var i = Input.linkToHtmlInput( level.worldX, jForm.find("#worldX"));
		i.onChange = ()->onFieldChange();
		i.fixValue = v->project.snapWorldGridX(v,false);

		var i = Input.linkToHtmlInput( level.worldY, jForm.find("#worldY"));
		i.onChange = ()->onFieldChange();
		i.fixValue = v->project.snapWorldGridY(v,false);

		// Size
		var tmpWid = level.pxWid;
		var tmpHei = level.pxHei;
		var e = jForm.find("#width"); e.replaceWith( e.clone() ); // block undo/redo
		var i = Input.linkToHtmlInput( tmpWid, jForm.find("#width") );
		i.setBounds(project.defaultGridSize*2, 4096);
		i.onValueChange = (v)->onLevelResized(v, tmpHei);
		i.fixValue = v->project.snapWorldGridX(v,true);

		var e = jForm.find("#height"); e.replaceWith( e.clone() ); // block undo/redo
		var i = Input.linkToHtmlInput( tmpHei, jForm.find("#height"));
		i.setBounds(project.defaultGridSize*2, 4096);
		i.onValueChange = (v)->onLevelResized(tmpWid, v);
		i.fixValue = v->project.snapWorldGridY(v,true);

		// Bg color
		var c = level.getBgColor();
		var i = Input.linkToHtmlInput( c, jForm.find("#bgColor"));
		i.isColorCode = true;
		i.onChange = ()->{
			level.bgColor = c==project.defaultLevelBgColor ? null : c;
			onFieldChange();
		}
		var jSetDefault = i.jInput.siblings("a.reset");
		if( level.bgColor==null )
			jSetDefault.hide();
		else
			jSetDefault.show();
		jSetDefault.click( (_)->{
			level.bgColor = null;
			onFieldChange();
		});
		var jIsDefault = i.jInput.siblings("span.usingDefault").hide();
		if( level.bgColor==null )
			jIsDefault.show();
		else
			jIsDefault.hide();

		// Create bg image picker
		jForm.find(".bg .imagePicker").remove();
		var jImg = JsTools.createImagePicker(level.bgRelPath, (?relPath)->{
			var old = level.bgRelPath;
			if( relPath==null && old!=null ) {
				// Remove
				level.bgRelPath = null;
				level.bgPos = null;
				editor.watcher.stopWatchingRel( old );
			}
			else if( relPath!=null ) {
				// Add or update
				level.bgRelPath = relPath;
				if( old!=null )
					editor.watcher.stopWatchingRel( old );
				editor.watcher.watchImage(relPath);
				if( old==null )
					level.bgPos = Cover;
			}
			onFieldChange();
		});
		jImg.insertAfter( jForm.find(".bg>label:first-of-type") );

		if( level.bgRelPath!=null )
			jForm.find(".bg .pos").show();
		else
			jForm.find(".bg .pos").hide();


		// Bg position
		var jSelect = jForm.find("#bgPos");
		jSelect.empty();
		if( level.bgPos!=null ) {
			for(k in ldtk.Json.BgImagePos.getConstructors()) {
				var e = ldtk.Json.BgImagePos.createByName(k);
				var jOpt = new J('<option value="$k"/>');
				jSelect.append(jOpt);
				jOpt.text( switch e {
					case Unscaled: Lang.t._("Not scaled");
					case Contain: Lang.t._("Fit inside (keep aspect ratio)");
					case Cover: Lang.t._("Cover level (keep aspect ratio)");
					case CoverDirty: Lang.t._("Cover (dirty scaling)");
				});
			}
			jSelect.val( level.bgPos.getName() );
			jSelect.change( (_)->{
				level.bgPos = ldtk.Json.BgImagePos.createByName( jSelect.val() );
				onFieldChange();
			});
		}

		// Bg pivot
		var jPivot = jForm.find(".pos>.pivot");
		jPivot.empty();
		if( level.bgRelPath!=null )
			jPivot.append( JsTools.createPivotEditor(level.bgPivotX, level.bgPivotY, (x,y)->{
				level.bgPivotX = x;
				level.bgPivotY = y;
				onFieldChange();
			}) );

		// Custom fields
		// ... (not implemented yet)

		JsTools.parseComponents(jForm);
	}

	override function update() {
		super.update();

		if( !editor.worldMode )
			close();

		if( !editor.worldTool.isInAddMode() && jContent.find("button.create.running").length>0 )
			jContent.find("button.create").removeClass("running");
	}
}