package ui.modal.panel;

class EditEntityDefs extends ui.modal.Panel {
	static var LAST_ENTITY_ID = -1;
	static var LAST_FIELD_ID = -1;

	var jEntityList(get,never) : js.jquery.JQuery; inline function get_jEntityList() return jContent.find(".entityList ul");
	var jFieldList(get,never) : js.jquery.JQuery; inline function get_jFieldList() return jContent.find(".fieldList ul");

	var jEntityForm(get,never) : js.jquery.JQuery; inline function get_jEntityForm() return jContent.find(".entityForm>ul.form");
	var jFieldForm(get,never) : js.jquery.JQuery; inline function get_jFieldForm() return jContent.find(".fieldForm>ul.form");
	var jPreview(get,never) : js.jquery.JQuery; inline function get_jPreview() return jContent.find(".previewWrapper");

	var curEntity : Null<led.def.EntityDef>;
	var curField : Null<led.def.FieldDef>;

	public function new() {
		super();

		loadTemplate( "editEntityDefs", "defEditor entityDefs" );
		linkToButton("button.editEntities");

		// Create entity
		jEntityList.parent().find("button.create").click( function(_) {
			var ed = project.defs.createEntityDef();
			selectEntity(ed);
			client.ge.emit(EntityDefAdded);
			jEntityForm.find("input").first().focus().select();
		});

		// Delete entity
		jEntityList.parent().find("button.delete").click( function(ev) {
			if( curEntity==null ) {
				N.error("No entity selected.");
				return;
			}
			new ui.modal.dialog.Confirm(ev.getThis(), Lang.t._("This operation cannot be canceled!"), function() {
				project.defs.removeEntityDef(curEntity);
				client.ge.emit(EntityDefRemoved);
				if( project.defs.entities.length>0 )
					selectEntity(project.defs.entities[0]);
				else
					selectEntity(null);
			});
		});

		// Create field
		jFieldList.parent().find("button.create").click( function(ev) {
			var anchor = ev.getThis();
			function _create(type:led.LedTypes.FieldType) {
				switch type {
					case F_Enum(null):
						// Enum picker
						var w = new ui.modal.Dialog(anchor, "enums");
						if( project.defs.enums.length==0 ) {
							w.jContent.append('<div class="warning">You first need to create an ENUM from the Project tab.</div>');
						}

						for(ed in project.defs.enums) {
							var b = new J("<button/>");
							b.appendTo(w.jContent);
							b.text(ed.identifier);
							b.click( function(_) {
								_create(F_Enum(ed.uid));
								w.close();
							});
						}
						return;


					case _:
				}
				var f = curEntity.createFieldDef(project, type);
				client.ge.emit(EntityFieldAdded);
				selectField(f);
				jFieldForm.find("input:first").focus().select();
			}

			// Type picker
			var w = new ui.modal.Dialog(anchor,"fieldTypes");
			var types : Array<led.LedTypes.FieldType> = [
				F_Int, F_Float, F_Bool, F_String, F_Enum(null), F_Color
			];
			for(type in types) {
				var b = new J("<button/>");
				w.jContent.append(b);
				JsTools.createFieldTypeIcon(type, b);
				b.click( function(ev) {
					_create(type);
					w.close();
				});
			}
		});

		// Delete field
		jFieldList.parent().find("button.delete").click( function(ev) {
			if( curField==null ) {
				N.error("No field selected.");
				return;
			}

			new ui.modal.dialog.Confirm(ev.getThis(), function() {
				curEntity.removeField(project, curField);
				client.ge.emit(EntityFieldRemoved);
				selectField( curEntity.fieldDefs[0] );
			});
		});

		// Select same entity as current client selection
		var lastFieldId = LAST_FIELD_ID; // because selectEntity changes it
		if( client.curLayerDef!=null && client.curLayerDef.type==Entities )
			selectEntity( project.defs.getEntityDef(client.curTool.getSelectedValue()) );
		else if( LAST_ENTITY_ID>=0 && project.defs.getEntityDef(LAST_ENTITY_ID)!=null )
			selectEntity( project.defs.getEntityDef(LAST_ENTITY_ID) );
		else
			selectEntity(project.defs.entities[0]);

		// Re-select last field
		if( lastFieldId>=0 && curEntity!=null && curEntity.getFieldDef(lastFieldId)!=null )
			selectField( curEntity.getFieldDef(lastFieldId) );
	}

	override function onGlobalEvent(e:GlobalEvent) {
		super.onGlobalEvent(e);
		switch e {
			case ProjectSettingsChanged, ProjectSelected, LevelSettingsChanged, LevelSelected:
				close();

			case LayerInstanceRestoredFromHistory:
				updatePreview();
				updateEntityForm();
				updateFieldForm();
				updateLists();

			case EntityDefChanged, EntityDefAdded, EntityDefRemoved:
				updatePreview();
				updateEntityForm();
				updateFieldForm();
				updateLists();

			case EntityDefSorted, EntityFieldSorted:
				updateLists();

			case EntityFieldAdded, EntityFieldRemoved, EntityFieldDefChanged:
				updateLists();
				updateFieldForm();

			case _:
		}
	}

	function selectEntity(ed:Null<led.def.EntityDef>) {
		if( ed==null )
			ed = client.project.defs.entities[0];

		curEntity = ed;
		curField = ed==null ? null : ed.fieldDefs[0];
		LAST_ENTITY_ID = curEntity==null ? -1 : curEntity.uid;
		LAST_FIELD_ID = curField==null ? -1 : curField.uid;
		updatePreview();
		updateEntityForm();
		updateFieldForm();
		updateLists();
	}

	function selectField(fd:led.def.FieldDef) {
		curField = fd;
		LAST_FIELD_ID = curField==null ? -1 : curField.uid;
		updateFieldForm();
		updateLists();
	}


	function updateEntityForm() {
		jEntityForm.find("*").off(); // cleanup event listeners

		var jAll = jEntityForm.add( jFieldForm ).add( jFieldList.parent() ).add( jPreview );
		if( curEntity==null ) {
			jAll.css("visibility","hidden");
			jContent.find(".none").show();
			jContent.find(".noEntLayer").hide();
			return;
		}

		JsTools.parseComponents(jEntityForm);
		jAll.css("visibility","visible");
		jContent.find(".none").hide();
		if( !project.defs.hasLayerType(Entities) )
			jContent.find(".noEntLayer").show();
		else
			jContent.find(".noEntLayer").hide();


		// Name
		var i = Input.linkToHtmlInput(curEntity.identifier, jEntityForm.find("input[name='name']") );
		i.validityCheck = function(id) return led.Project.isValidIdentifier(id) && project.defs.isEntityIdentifierUnique(id);
		i.validityError = N.invalidIdentifier;
		i.linkEvent(EntityDefChanged);

		// Dimensions
		var i = Input.linkToHtmlInput( curEntity.width, jEntityForm.find("input[name='width']") );
		i.setBounds(1,256);
		i.onChange = client.ge.emit.bind(EntityDefChanged);

		var i = Input.linkToHtmlInput( curEntity.height, jEntityForm.find("input[name='height']") );
		i.setBounds(1,256);
		i.onChange = client.ge.emit.bind(EntityDefChanged);

		// Color
		var col = jEntityForm.find("input[name=color]");
		col.val( C.intToHex(curEntity.color) );
		col.change( function(ev) {
			curEntity.color = C.hexToInt( col.val() );
			client.ge.emit(EntityDefChanged);
			updateEntityForm();
		});

		// Max per level
		var i = Input.linkToHtmlInput(curEntity.maxPerLevel, jEntityForm.find("input[name='maxPerLevel']") );
		i.setBounds(0,1024);
		i.onChange = client.ge.emit.bind(EntityDefChanged);

		// Behavior when max is reached
		var i = new form.input.BoolInput(
			jEntityForm.find("select[name=discardExcess"),
			function() return curEntity.discardExcess,
			function(v) curEntity.discardExcess = v
		);
		i.setEnabled( curEntity.maxPerLevel>0 );
		i.linkEvent(EntityDefChanged);

		// Pivot
		var jPivots = jEntityForm.find(".pivot");
		jPivots.empty();
		var p = JsTools.createPivotEditor(curEntity.pivotX, curEntity.pivotY, curEntity.color, function(x,y) {
			curEntity.pivotX = x;
			curEntity.pivotY = y;
			client.ge.emit(EntityDefChanged);
		});
		jPivots.append(p);
	}


	function updateFieldForm() {
		jFieldForm.find("*").off(); // cleanup events

		if( curField==null ) {
			jFieldForm.css("visibility","hidden");
			return;
		}
		else
			jFieldForm.css("visibility","visible");

		JsTools.parseComponents(jFieldForm);

		// Set form class
		for(k in Type.getEnumConstructs(led.LedTypes.FieldType))
			jFieldForm.removeClass("type-"+k);
		jFieldForm.addClass("type-"+curField.type.getName());

		jFieldForm.find(".type").empty().append( curField.getShortDescription() );

		var i = new form.input.EnumSelect(
			jFieldForm.find("select[name=editorDisplayMode]"),
			led.LedTypes.FieldDisplayMode,
			function() return curField.editorDisplayMode,
			function(v) return curField.editorDisplayMode = v
		);
		i.linkEvent(EntityFieldDefChanged);

		var i = new form.input.EnumSelect(
			jFieldForm.find("select[name=editorDisplayPos]"),
			led.LedTypes.FieldDisplayPosition,
			function() return curField.editorDisplayPos,
			function(v) return curField.editorDisplayPos = v
		);
		i.setEnabled( curField.editorDisplayMode!=Hidden );
		i.linkEvent(EntityFieldDefChanged);

		var i = Input.linkToHtmlInput( curField.identifier, jFieldForm.find("input[name=name]") );
		i.linkEvent(EntityFieldDefChanged);
		i.validityCheck = function(id) {
			return led.Project.isValidIdentifier(id) && curEntity.isFieldIdentifierUnique(id);
		}
		i.validityError = N.invalidIdentifier;

		// Default value
		switch curField.type {
			case F_Int, F_Float, F_String:
				var defInput = jFieldForm.find("input[name=fDef]");
				if( curField.defaultOverride != null )
					defInput.val( Std.string( curField.getUntypedDefault() ) );
				else
					defInput.val("");

				if( curField.type==F_String && !curField.canBeNull )
					defInput.attr("placeholder", "(empty string)");
				else if( curField.canBeNull )
					defInput.attr("placeholder", "(null)");
				else
					defInput.attr("placeholder", switch curField.type {
						case F_Int: Std.string( curField.iClamp(0) );
						case F_Float: Std.string( curField.fClamp(0) );
						case F_String: "";
						case F_Bool, F_Color, F_Enum(_): "N/A";
					});

				defInput.change( function(ev) {
					curField.setDefault( defInput.val() );
					client.ge.emit(EntityFieldDefChanged);
					defInput.val( curField.defaultOverride==null ? "" : Std.string(curField.getUntypedDefault()) );
				});

			case F_Enum(name):
				var ed = project.defs.getEnumDef(name);
				var enumDef = jFieldForm.find("[name=enumDef]");
				enumDef.find("[value]").remove();
				if( curField.canBeNull ) {
					var opt = new J('<option/>');
					opt.appendTo(enumDef);
					opt.attr("value","");
					opt.text("-- null --");
					if( curField.getEnumDefault()==null )
						opt.attr("selected","selected");
				}
				for(v in ed.values) {
					var opt = new J('<option/>');
					opt.appendTo(enumDef);
					opt.attr("value",v);
					opt.text(v);
					if( curField.getEnumDefault()==v )
						opt.attr("selected","selected");
				}

				enumDef.change( function(ev) {
					var v = enumDef.val();
					N.debug(v);
					if( v=="" && curField.canBeNull )
						curField.setDefault(null);
					else if( v!="" )
						curField.setDefault(v);
					client.ge.emit(EntityFieldDefChanged);
				});

			case F_Color:
				var defInput = jFieldForm.find("input[name=cDef]");
				defInput.val( C.intToHex(curField.getColorDefault()) );
				defInput.change( function(ev) {
					curField.setDefault( defInput.val() );
					client.ge.emit(EntityFieldDefChanged);
				});

			case F_Bool:
				var defInput = jFieldForm.find("input[name=bDef]");
				defInput.prop("checked", curField.getBoolDefault());
				defInput.change( function(ev) {
					var checked = defInput.prop("checked") == true;
					curField.setDefault( Std.string(checked) );
					client.ge.emit(EntityFieldDefChanged);
				});
		}

		// Nullable
		var i = Input.linkToHtmlInput( curField.canBeNull, jFieldForm.find("input[name=canBeNull]") );
		i.onChange = client.ge.emit.bind(EntityFieldDefChanged);

		// Min
		var input = jFieldForm.find("input[name=min]");
		input.val( curField.min==null ? "" : curField.min );
		input.change( function(ev) {
			curField.setMin( input.val() );
			client.ge.emit(EntityFieldDefChanged);
		});

		// Max
		var input = jFieldForm.find("input[name=max]");
		input.val( curField.max==null ? "" : curField.max );
		input.change( function(ev) {
			curField.setMax( input.val() );
			client.ge.emit(EntityFieldDefChanged);
		});
	}


	function updateLists() {
		jEntityList.empty();
		jFieldList.empty();

		// Entities
		for(ed in project.defs.entities) {
			var elem = new J("<li/>");
			jEntityList.append(elem);
			elem.addClass("iconLeft");

			var preview = JsTools.createEntityPreview(ed, 32);
			preview.appendTo(elem);

			elem.append('<span class="name">'+ed.identifier+'</span>');
			if( curEntity==ed ) {
				elem.addClass("active");
				elem.css( "background-color", C.intToHex( C.toWhite(ed.color, 0.5) ) );
			}
			else
				elem.css( "color", C.intToHex( C.toWhite(ed.color, 0.5) ) );

			elem.click( function(_) selectEntity(ed) );
		}

		// Make layer list sortable
		JsTools.makeSortable(".entityList ul", function(from, to) {
			var moved = project.defs.sortEntityDef(from,to);
			selectEntity(moved);
			client.ge.emit(EntityDefSorted);
		});

		// Fields
		if( curEntity!=null ) {
			for(f in curEntity.fieldDefs) {
				var li = new J("<li/>");
				li.appendTo(jFieldList);
				li.append('<span class="name">'+f.identifier+'</span>');
				if( curField==f )
					li.addClass("active");

				var sub = new J('<span class="sub"></span>');
				sub.appendTo(li);
				sub.text( f.getShortDescription() );

				li.click( function(_) selectField(f) );
			}
		}

		// Make fields list sortable
		JsTools.makeSortable(".window .fieldList ul", function(from, to) {
			var moved = curEntity.sortField(from,to);
			selectField(moved);
			client.ge.emit(EntityFieldSorted);
		});
	}


	function updatePreview() {
		if( curEntity==null )
			return;

		jPreview.children(".entityPreview").remove();
		jPreview.append( JsTools.createEntityPreview(curEntity) );
	}
}
