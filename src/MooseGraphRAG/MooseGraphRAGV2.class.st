Class {
	#name : 'MooseGraphRAGV2',
	#superclass : 'Object',
	#instVars : [
		'model',
		'arrowLibrary',
		'gLibrary',
		'parquetLibrary',
		'outputPath',
		'methodTextUnitMap',
		'entityRelationshipMap',
		'filteredFamixEntities',
		'documentEntitiesMap'
	],
	#category : 'MooseGraphRAG-GraphRAGV2',
	#package : 'MooseGraphRAG',
	#tag : 'GraphRAGV2'
}

{ #category : 'customization' }
MooseGraphRAGV2 >> addFilteredFamixEntities: anCollectionOfFamixTypes [

	filteredFamixEntities addAll: anCollectionOfFamixTypes asSet
]

{ #category : 'customization' }
MooseGraphRAGV2 >> addFilteredFamixEntity: FamixTypes [

	self addFilteredFamixEntities: {FamixTypes}
]

{ #category : 'private' }
MooseGraphRAGV2 >> appendStrings: aCollection toListBuilder: listBuilder [
    "Append a list of strings to an Arrow ListArrayBuilder using its value builder"
    | innerBuilder |
    innerBuilder := arrowLibrary garrow_list_array_builder_get_value_builder: listBuilder.
    arrowLibrary garrow_list_array_builder_append_value: listBuilder error: nil.
    (self safeStringCollection: aCollection) do: [ :str |
        arrowLibrary
            garrow_string_array_builder: innerBuilder
            _append_string: str
            error: nil ]
]

{ #category : 'building' }
MooseGraphRAGV2 >> buildDocumentsColumns [

	| idBuilder humanIdBuilder textBuilder entityLstType rawDataBuilder entityIdsBuilder idArray humanIdArray textArray entityIdsArray rawDataArray columns rowCounter titleBuilder creationDateBuilder titleArray creationDateArray |
	"declare table colums type"
	entityLstType := arrowLibrary garrow_list_data_type_new:
		                 (arrowLibrary
			                  garrow_field_new: 'entity_id'
			                  dataType:
			                  arrowLibrary garrow_string_data_type_new).

	idBuilder := arrowLibrary garrow_string_array_builder_new.
	humanIdBuilder := arrowLibrary garrow_int64_array_builder_new.
	textBuilder := arrowLibrary garrow_string_array_builder_new.
	rawDataBuilder := arrowLibrary garrow_string_array_builder_new.
	titleBuilder := arrowLibrary garrow_string_array_builder_new.
	creationDateBuilder := arrowLibrary garrow_string_array_builder_new.
	entityIdsBuilder := arrowLibrary
		                    garrow_list_array_builder_new: entityLstType
		                    error: nil.

	rowCounter := 0.

	"put values inside columns  for each entity"
	self documentEntities do: [ :documentPath |
			| doc txt docId entityIds title entities creationDate |
			"get values for each columns "
			entities := documentEntitiesMap at: documentPath.
			doc := entities first sourceAnchor.
			
			txt := self safeString: ([ doc completeText ]
					        on: Error
					        do: [ '' ]).

			title := self safeString: ([ doc fileName ]
					          on: Error
					          do: [ '' ]).

			"document id linked inside document.parquet (here java files)"
			docId := self safeString: doc fileName hash.

			"multiple entity can be extracted from the same text_unit, thus the following array."
			entityIds := OrderedCollection withAll:
				             (entities collect: [ :e | self safeString: e mooseID ]).

			creationDate := self safeString: doc fileReference creationTime.
					

			rowCounter := rowCounter + 1.

			"put the values in the proper columns"
			arrowLibrary
				garrow_string_array_builder: idBuilder
				_append_string: docId
				error: nil.
			arrowLibrary
				garrow_int64_array_builder: humanIdBuilder
				_append_value: rowCounter
				error: nil.
			arrowLibrary
				garrow_string_array_builder: textBuilder
				_append_string: txt
				error: nil.
			arrowLibrary
				garrow_string_array_builder: titleBuilder
				_append_string: title
				error: nil.
				
			self appendStrings: entityIds toListBuilder: entityIdsBuilder.
			
			arrowLibrary
				garrow_string_array_builder: creationDateBuilder
				_append_string: creationDate
				error: nil.

			arrowLibrary
				garrow_string_array_builder: rawDataBuilder 
				_append_string: ''
				error: nil.
			 ].


	idArray := arrowLibrary
		           garrow_array_builder_finish: idBuilder
		           error: nil.
	humanIdArray := arrowLibrary
		                garrow_array_builder_finish: humanIdBuilder
		                error: nil.
	textArray := arrowLibrary
		             garrow_array_builder_finish: textBuilder
		             error: nil.
	titleArray := arrowLibrary
		              garrow_array_builder_finish: titleBuilder
		              error: nil.
	creationDateArray := arrowLibrary
		                     garrow_array_builder_finish:
		                     creationDateBuilder
		                     error: nil.
		
	rawDataArray := arrowLibrary
		                  garrow_array_builder_finish: rawDataBuilder 
		                  error: nil.
	entityIdsArray := arrowLibrary
		                  garrow_array_builder_finish: entityIdsBuilder
		                  error: nil.



	columns := nil.
	columns := gLibrary g_list_append: columns with: idArray.
	columns := gLibrary g_list_append: columns with: humanIdArray.
	columns := gLibrary g_list_append: columns with: titleArray.
	columns := gLibrary g_list_append: columns with: textArray.
	columns := gLibrary g_list_append: columns with: entityIdsArray.
	columns := gLibrary g_list_append: columns with: creationDateArray.
	columns := gLibrary g_list_append: columns with: rawDataArray .


	^ columns
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> buildDocumentsParquet [

	| schema columns table |
	schema := self prepareDocumentsSchema.
	columns := self buildDocumentsColumns.

	table := arrowLibrary
		         garrow_table_new_values: schema
		         values: columns
		         error: nil.
	self writeTable: table schema: schema toFile: 'documents.parquet'
]

{ #category : 'building' }
MooseGraphRAGV2 >> buildEntitiesColumns [

	| idBuilder humanIdBuilder titleBuilder typeBuilder descriptionBuilder textUnitLstType textUnitIdsBuilder degreeBuilder idArray humanIdArray titleArray typeArray descriptionArray textUnitIdsArray degreeArray columns |
	"initialize each column type"
	textUnitLstType := arrowLibrary garrow_list_data_type_new:
		                   (arrowLibrary
			                    garrow_field_new: 'text_unit_id'
			                    dataType:
			                    arrowLibrary garrow_string_data_type_new).
	idBuilder := arrowLibrary garrow_string_array_builder_new.
	humanIdBuilder := arrowLibrary garrow_int64_array_builder_new.
	titleBuilder := arrowLibrary garrow_string_array_builder_new.
	typeBuilder := arrowLibrary garrow_string_array_builder_new.
	descriptionBuilder := arrowLibrary garrow_string_array_builder_new.
	textUnitIdsBuilder := arrowLibrary
		                      garrow_list_array_builder_new: textUnitLstType
		                      error: nil.
	degreeBuilder := arrowLibrary garrow_int64_array_builder_new.

	"for each model's entity set up a row with each columns values"
	self entitiesToExport do: [ :entity |
			| normalizedType |
			normalizedType := self safeString: (self normalizedTypeOf: entity).
			arrowLibrary
				garrow_string_array_builder: idBuilder
				_append_string: (self safeString: entity mooseID)
				error: nil.
			arrowLibrary
				garrow_int64_array_builder: humanIdBuilder
				_append_value: entity mooseID
				error: nil.
			arrowLibrary
				garrow_string_array_builder: titleBuilder
				_append_string: (self safeString: (self nameOf: entity))
				error: nil.
			arrowLibrary
				garrow_string_array_builder: typeBuilder
				_append_string: normalizedType
				error: nil.
			arrowLibrary
				garrow_string_array_builder: descriptionBuilder
				_append_string: normalizedType
				error: nil.
			self flag: 'WARNING: ensure methodTextUnitMap is setup'.
			self
				appendStrings: (self textUnitIdsFor: entity)
				toListBuilder: textUnitIdsBuilder.
			arrowLibrary
				garrow_int64_array_builder: degreeBuilder
				_append_value: 1
				error: nil ].

	"finalize columns references"
	idArray := arrowLibrary
		           garrow_array_builder_finish: idBuilder
		           error: nil.
	humanIdArray := arrowLibrary
		                garrow_array_builder_finish: humanIdBuilder
		                error: nil.
	titleArray := arrowLibrary
		              garrow_array_builder_finish: titleBuilder
		              error: nil.
	typeArray := arrowLibrary
		             garrow_array_builder_finish: typeBuilder
		             error: nil.
	descriptionArray := arrowLibrary
		                    garrow_array_builder_finish: descriptionBuilder
		                    error: nil.
	textUnitIdsArray := arrowLibrary
		                    garrow_array_builder_finish: textUnitIdsBuilder
		                    error: nil.
	degreeArray := arrowLibrary
		               garrow_array_builder_finish: degreeBuilder
		               error: nil.

	"append coloumns to form the table "
	columns := nil.
	columns := gLibrary g_list_append: columns with: idArray.
	columns := gLibrary g_list_append: columns with: humanIdArray.
	columns := gLibrary g_list_append: columns with: titleArray.
	columns := gLibrary g_list_append: columns with: typeArray.
	columns := gLibrary g_list_append: columns with: descriptionArray.
	columns := gLibrary g_list_append: columns with: textUnitIdsArray.
	columns := gLibrary g_list_append: columns with: degreeArray.


	^ columns
]

{ #category : 'building' }
MooseGraphRAGV2 >> buildEntitiesColumns: schema [

	| idBuilder humanIdBuilder titleBuilder typeBuilder descriptionBuilder textUnitIdsBuilder idArray humanIdArray titleArray typeArray descriptionArray textUnitIdsArray columns |
	"--- builders ---"
	self
		deprecated: 'Use buildEntitiesColumns instead of current one'
		on: '9 July 2026'
		in:
		'Pharo-13.1.0+SNAPSHOT.build.731.sha.c4d03ecd531b9f32fcc7cd9e3b61728bce0d4c7f (64 Bit)'.
	idBuilder := arrowLibrary garrow_string_array_builder_new.
	humanIdBuilder := arrowLibrary garrow_int64_array_builder_new.
	titleBuilder := arrowLibrary garrow_string_array_builder_new.
	typeBuilder := arrowLibrary garrow_string_array_builder_new.
	descriptionBuilder := arrowLibrary garrow_string_array_builder_new.

	textUnitIdsBuilder := arrowLibrary
		                      garrow_list_array_builder_new:
			                      (arrowLibrary garrow_list_data_type_new:
				                       (arrowLibrary
					                        garrow_field_new: 'text_unit_id'
					                        dataType:
					                        arrowLibrary garrow_string_data_type_new))
		                      error: nil.
	"--- fill rows ---"
	self entitiesToExport do: [ :entity |
			arrowLibrary
				garrow_string_array_builder: idBuilder
				_append_string: entity mooseID printString
				error: nil.
			arrowLibrary
				garrow_int64_array_builder: humanIdBuilder
				_append_value: entity mooseID
				error: nil.
			arrowLibrary
				garrow_string_array_builder: titleBuilder
				_append_string: (self nameOf: entity)
				error: nil.
			arrowLibrary
				garrow_string_array_builder: typeBuilder
				_append_string: entity class name
				error: nil.
			arrowLibrary
				garrow_string_array_builder: descriptionBuilder
				_append_string: entity class name
				error: nil.
			self
				appendStrings: (self textUnitIdsFor: entity)
				toListBuilder: textUnitIdsBuilder.
			"degree placeholder - TODO compute actual degree"
			arrowLibrary garrow_int64_array_builder_new ].
	"reuse a degree builder properly"
	^ nil
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> buildEntitiesParquet [
    | schema columns table |
    schema := self prepareEntitiesSchema.
    columns := self buildEntitiesColumns.
    table := arrowLibrary garrow_table_new_values: schema values: columns error: nil.
    self writeTable: table schema: schema toFile: 'entities.parquet'
]

{ #category : 'building' }
MooseGraphRAGV2 >> buildRelationshipsColumns [
    | idBuilder humanIdBuilder sourceBuilder targetBuilder descriptionBuilder
      weightBuilder textUnitLstType textUnitIdsBuilder combinedDegreeBuilder
      idArray humanIdArray sourceArray targetArray descriptionArray weightArray
      textUnitIdsArray combinedDegreeArray columns relCounter |
    textUnitLstType := arrowLibrary garrow_list_data_type_new:
        (arrowLibrary garrow_field_new: 'text_unit_id'
            dataType: arrowLibrary garrow_string_data_type_new).
    idBuilder := arrowLibrary garrow_string_array_builder_new.
    humanIdBuilder := arrowLibrary garrow_int64_array_builder_new.
    sourceBuilder := arrowLibrary garrow_string_array_builder_new.
    targetBuilder := arrowLibrary garrow_string_array_builder_new.
    descriptionBuilder := arrowLibrary garrow_string_array_builder_new.
    weightBuilder := arrowLibrary garrow_float_array_builder_new.
    textUnitIdsBuilder := arrowLibrary garrow_list_array_builder_new: textUnitLstType error: nil.
    combinedDegreeBuilder := arrowLibrary garrow_int64_array_builder_new.
    relCounter := 0.
    self relationshipRecords do: [ :record |
        | relId source target description textUnitIds |
        relId := self safeString: record first.
        source := record second.
        target := record third.
        description := self safeString: record fourth.
        textUnitIds := self effectiveTextUnitIdsForSource: source target: target candidateIds: record fifth.
        relCounter := relCounter + 1.
        arrowLibrary garrow_string_array_builder: idBuilder _append_string: relId error: nil.
        arrowLibrary garrow_int64_array_builder: humanIdBuilder _append_value: relCounter error: nil.
        arrowLibrary garrow_string_array_builder: sourceBuilder _append_string: (self safeString: (self nameOf: source)) error: nil.
        arrowLibrary garrow_string_array_builder: targetBuilder _append_string: (self safeString: (self nameOf: target)) error: nil.
        arrowLibrary garrow_string_array_builder: descriptionBuilder _append_string: description error: nil.
        weightBuilder append: 1.0.
        self appendStrings: textUnitIds toListBuilder: textUnitIdsBuilder.
        arrowLibrary garrow_int64_array_builder: combinedDegreeBuilder _append_value: 2 error: nil ].
    idArray := arrowLibrary garrow_array_builder_finish: idBuilder error: nil.
    humanIdArray := arrowLibrary garrow_array_builder_finish: humanIdBuilder error: nil.
    sourceArray := arrowLibrary garrow_array_builder_finish: sourceBuilder error: nil.
    targetArray := arrowLibrary garrow_array_builder_finish: targetBuilder error: nil.
    descriptionArray := arrowLibrary garrow_array_builder_finish: descriptionBuilder error: nil.
    weightArray := weightBuilder finish.
    textUnitIdsArray := arrowLibrary garrow_array_builder_finish: textUnitIdsBuilder error: nil.
    combinedDegreeArray := arrowLibrary garrow_array_builder_finish: combinedDegreeBuilder error: nil.
    columns := nil.
    columns := gLibrary g_list_append: columns with: idArray.
    columns := gLibrary g_list_append: columns with: humanIdArray.
    columns := gLibrary g_list_append: columns with: sourceArray.
    columns := gLibrary g_list_append: columns with: targetArray.
    columns := gLibrary g_list_append: columns with: descriptionArray.
    columns := gLibrary g_list_append: columns with: weightArray.
    columns := gLibrary g_list_append: columns with: textUnitIdsArray.
    columns := gLibrary g_list_append: columns with: combinedDegreeArray.
    ^ columns
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> buildRelationshipsParquet [
    | schema columns table |
    schema := self prepareRelationshipsSchema.
    columns := self buildRelationshipsColumns.
    table := arrowLibrary garrow_table_new_values: schema values: columns error: nil.
    self writeTable: table schema: schema toFile: 'relationships.parquet'
]

{ #category : 'building' }
MooseGraphRAGV2 >> buildTextUnitsColumns [

	| idBuilder humanIdBuilder textBuilder nTokensBuilder documentIdBuilder entityLstType entityIdsBuilder relLstType relIdsBuilder idArray humanIdArray textArray nTokensArray documentIdArray entityIdsArray relIdsArray columns rowCounter |
	"declare table colums type"
	self flag: 'TODO: methods for each columns builder'.
	entityLstType := arrowLibrary garrow_list_data_type_new:
		                 (arrowLibrary
			                  garrow_field_new: 'entity_id'
			                  dataType:
			                  arrowLibrary garrow_string_data_type_new).
	relLstType := arrowLibrary garrow_list_data_type_new: (arrowLibrary
			               garrow_field_new: 'relationship_id'
			               dataType: arrowLibrary garrow_string_data_type_new).
	idBuilder := arrowLibrary garrow_string_array_builder_new.
	humanIdBuilder := arrowLibrary garrow_int64_array_builder_new.
	textBuilder := arrowLibrary garrow_string_array_builder_new.
	nTokensBuilder := arrowLibrary garrow_int64_array_builder_new.
	documentIdBuilder := arrowLibrary garrow_string_array_builder_new.
	entityIdsBuilder := arrowLibrary
		                    garrow_list_array_builder_new: entityLstType
		                    error: nil.
	relIdsBuilder := arrowLibrary
		                 garrow_list_array_builder_new: relLstType
		                 error: nil.
	rowCounter := 0.

	"put values inside columns  for each entity"
	self textUnitEntities do: [ :entity |
			| txt nTokens docId entityIds relIds |
			"get values for each columns "
			txt := self safeString: ([ entity sourceAnchor sourceText ]
					        on: Error
					        do: [ '' ]).
			nTokens := txt size // 4 max: 1.

			"document id linked inside document.parquet (here java files)"
			docId := self safeString: entity mooseID.

			"multiple entity can be extracted from the same text_unit, thus the following array."
			entityIds := OrderedCollection with:
				             (self safeString: entity mooseID).
			"(entity respondsTo: #parentType) ifTrue: [
					| pt |
					pt := [ entity parentType ]
						      on: Error
						      do: [ nil ].
					pt isNil ifFalse: [ entityIds add: (self safeString: pt mooseID) ] ]."

			relIds := self safeStringCollection:
				          (self relationshipIdsFor: entity sourceAnchor).

			rowCounter := rowCounter + 1.

			"put the values in the proper columns"
			arrowLibrary
				garrow_string_array_builder: idBuilder
				_append_string: (self safeString: entity sourceAnchor mooseID)
				error: nil.
			arrowLibrary
				garrow_int64_array_builder: humanIdBuilder
				_append_value: rowCounter
				error: nil.
			arrowLibrary
				garrow_string_array_builder: textBuilder
				_append_string: txt
				error: nil.
			arrowLibrary
				garrow_int64_array_builder: nTokensBuilder
				_append_value: nTokens
				error: nil.
			arrowLibrary
				garrow_string_array_builder: documentIdBuilder
				_append_string: docId
				error: nil.
			self appendStrings: entityIds toListBuilder: entityIdsBuilder.
			self appendStrings: relIds toListBuilder: relIdsBuilder ].



	idArray := arrowLibrary
		           garrow_array_builder_finish: idBuilder
		           error: nil.
	humanIdArray := arrowLibrary
		                garrow_array_builder_finish: humanIdBuilder
		                error: nil.
	textArray := arrowLibrary
		             garrow_array_builder_finish: textBuilder
		             error: nil.
	nTokensArray := arrowLibrary
		                garrow_array_builder_finish: nTokensBuilder
		                error: nil.
	documentIdArray := arrowLibrary
		                   garrow_array_builder_finish: documentIdBuilder
		                   error: nil.
	entityIdsArray := arrowLibrary
		                  garrow_array_builder_finish: entityIdsBuilder
		                  error: nil.
	relIdsArray := arrowLibrary
		               garrow_array_builder_finish: relIdsBuilder
		               error: nil.


	columns := nil.
	columns := gLibrary g_list_append: columns with: idArray.
	columns := gLibrary g_list_append: columns with: humanIdArray.
	columns := gLibrary g_list_append: columns with: textArray.
	columns := gLibrary g_list_append: columns with: nTokensArray.
	columns := gLibrary g_list_append: columns with: documentIdArray.
	columns := gLibrary g_list_append: columns with: entityIdsArray.
	columns := gLibrary g_list_append: columns with: relIdsArray.
	^ columns
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> buildTextUnitsParquet [
    | schema columns table |
    schema := self prepareTextUnitsSchema.
    columns := self buildTextUnitsColumns.
    table := arrowLibrary garrow_table_new_values: schema values: columns error: nil.
    self writeTable: table schema: schema toFile: 'text_units.parquet'
]

{ #category : 'private' }
MooseGraphRAGV2 >> computePrecomputedData [

	methodTextUnitMap := Dictionary new.
	entityRelationshipMap := Dictionary new.
	documentEntitiesMap := Dictionary new.

	

	self textUnitEntities do: [ :entity |
			self flag:
				'WARNING: check if methodTextUnitMap should be build here'.
			methodTextUnitMap at: entity mooseID put: entity sourceAnchor mooseID ].

	self relationshipRecords do: [ :record |
			| relId source relIds |
			relId := record first.
			source := record second.
			relIds := entityRelationshipMap
				          at: source mooseID
				          ifAbsentPut: [ OrderedCollection new ].
			relIds add: relId ].

	"Mapping document (java files) to entities (if not nil)"
	((self model allWithSubTypesOf: FamixJavaSourceAnchor) reject: [
		 :entity | entity element isNil ]) do: [ :entity |
			documentEntitiesMap
				at: entity fileName
				ifPresent: [ :dic |
						dic
							add: entity element;
							yourself ]
				ifAbsentPut: [
						OrderedCollection new
							add: entity element;
							yourself ] ]
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> documentEntities [
	
	^ documentEntitiesMap keys. 
"	^ (self model allWithSubTypesOf: FamixJavaSourceAnchor)
		  collectAsSet: [ :anchor | anchor fileReference ]"
]

{ #category : 'private' }
MooseGraphRAGV2 >> effectiveTextUnitIdsForSource: source target: target candidateIds: candidateIds [

	| merged |
	merged := OrderedCollection new.
	merged addAll: (self safeStringCollection: candidateIds).
	merged addAll: (self safeStringCollection: (self textUnitIdsFor: source)).
	merged addAll: (self safeStringCollection: (self textUnitIdsFor: target)).
	merged := merged asSet asOrderedCollection.
	merged ifEmpty: [ merged add: (self safeString: source mooseID) ].
	^ merged
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> entitiesToExport [
	"Classes, methods, and attributes from the model"

	^ self textUnitEntities
	"^ self model allModelEntities select: [ :entity |
		  entity isClass or: [ entity isMethod or: [ entity isAttribute ] ] ]"
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> export [
    "Export to the default outputPath (Documents folder)"
    self exportTo: outputPath
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> exportTo: aPath [
	"Main entry point. Export entities, relationships and text_units to aPath directory."

	outputPath := aPath.
	self computePrecomputedData.
	self buildDocumentsParquet. 
	self buildEntitiesParquet.
	self buildRelationshipsParquet.
	self buildTextUnitsParquet.
]

{ #category : 'customization' }
MooseGraphRAGV2 >> filteredFamixEntities [

	^ filteredFamixEntities 
]

{ #category : 'customization' }
MooseGraphRAGV2 >> filteredFamixEntities: anCollectionOfFamixTypes [

	filteredFamixEntities := anCollectionOfFamixTypes asSet
]

{ #category : 'initialization' }
MooseGraphRAGV2 >> initialize [

	super initialize.
	arrowLibrary := PharoArrowLibrary uniqueInstance.
	gLibrary := PharoGLibLibrary uniqueInstance.
	parquetLibrary := PharoParquetLibrary uniqueInstance.
	methodTextUnitMap := Dictionary new.
	entityRelationshipMap := Dictionary new.
	outputPath := FileLocator documents fullName.
	filteredFamixEntities := Set withAll: {FamixJavaClass . FamixJavaMethod . FamixJavaAttribute }
]

{ #category : 'private' }
MooseGraphRAGV2 >> invocationRelationshipRecords [
    | records invocations |
    records := OrderedCollection new.
    invocations := self model allModelEntities select: [ :entity |
        entity class name includesSubstring: 'Invocation' ].
    invocations do: [ :inv |
        | sender candidates |
        sender := [ inv sender ] on: Error do: [ nil ].
        candidates := [ inv candidates ] on: Error do: [ #() ].
        (sender isNil or: [ (sender respondsTo: #mooseID) not ]) ifFalse: [
            candidates do: [ :target |
                (target isNil not and: [ target respondsTo: #mooseID ]) ifTrue: [
                    records add: {
                        sender mooseID printString , '-invokes-' , target mooseID printString.
                        sender.
                        target.
                        'invokes'.
                        (self textUnitIdsFor: sender) } ] ] ] ].
    ^ records
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> model [
    ^ model
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> model: aModel [
    model := aModel
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> nameOf: aMooseConcept [
    ^ (self safeString: aMooseConcept mooseName)
        , '.'
        , (self safeString: aMooseConcept mooseID)
]

{ #category : 'private' }
MooseGraphRAGV2 >> normalizedTypeOf: entity [
    | className |
    className := entity class name.
    (className includesSubstring: 'Class') ifTrue: [ ^ 'class' ].
    (className includesSubstring: 'Method') ifTrue: [ ^ 'method' ].
    (className includesSubstring: 'Attribute') ifTrue: [ ^ 'attribute' ].
    (className includesSubstring: 'Invocation') ifTrue: [ ^ 'invocation' ].
    (className includesSubstring: 'Package') ifTrue: [ ^ 'package' ].
    ^ className asLowercase
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> outputPath [
    ^ outputPath
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> outputPath: aPath [
    outputPath := aPath
]

{ #category : 'schema' }
MooseGraphRAGV2 >> prepareDocumentsSchema [

	| strType intType idField humanIdField titleField textField textUnitIdField lstType textUnitIdsField creationDateField rawDataField fields |
	strType := arrowLibrary garrow_string_data_type_new.
	intType := arrowLibrary garrow_int64_data_type_new.
	idField := arrowLibrary garrow_field_new: 'id' dataType: strType.
	humanIdField := arrowLibrary
		                garrow_field_new: 'human_readable_id'
		                dataType: intType.
	titleField := arrowLibrary
		              garrow_field_new: 'title'
		              dataType: strType.
	textField := arrowLibrary garrow_field_new: 'text' dataType: strType.
	textUnitIdField := arrowLibrary
		                   garrow_field_new: 'text_unit_id'
		                   dataType: strType.
	lstType := arrowLibrary garrow_list_data_type_new: textUnitIdField.
	textUnitIdsField := arrowLibrary
		                    garrow_field_new: 'text_unit_ids'
		                    dataType: lstType.
		
	creationDateField := arrowLibrary
		               garrow_field_new: 'creation_date'
		               dataType: strType.	
	rawDataField := arrowLibrary
		               garrow_field_new: 'raw_data'
		               dataType: strType.
	fields := nil.
	fields := gLibrary g_list_append: fields with: idField.
	fields := gLibrary g_list_append: fields with: humanIdField.
	fields := gLibrary g_list_append: fields with: titleField.
	fields := gLibrary g_list_append: fields with: textField.
	fields := gLibrary g_list_append: fields with: textUnitIdsField.
	fields := gLibrary g_list_append: fields with: creationDateField.
	fields := gLibrary g_list_append: fields with: rawDataField.
	
	^ arrowLibrary garrow_schema_new: fields
]

{ #category : 'schema' }
MooseGraphRAGV2 >> prepareEntitiesSchema [
    | strType intType idField humanIdField titleField typeField descriptionField
      textUnitIdField lstType textUnitIdsField degreeField fields |
    strType := arrowLibrary garrow_string_data_type_new.
    intType := arrowLibrary garrow_int64_data_type_new.
    idField := arrowLibrary garrow_field_new: 'id' dataType: strType.
    humanIdField := arrowLibrary garrow_field_new: 'human_readable_id' dataType: intType.
    titleField := arrowLibrary garrow_field_new: 'title' dataType: strType.
    typeField := arrowLibrary garrow_field_new: 'type' dataType: strType.
    descriptionField := arrowLibrary garrow_field_new: 'description' dataType: strType.
    textUnitIdField := arrowLibrary garrow_field_new: 'text_unit_id' dataType: strType.
    lstType := arrowLibrary garrow_list_data_type_new: textUnitIdField.
    textUnitIdsField := arrowLibrary garrow_field_new: 'text_unit_ids' dataType: lstType.
    degreeField := arrowLibrary garrow_field_new: 'degree' dataType: intType.
    fields := nil.
    fields := gLibrary g_list_append: fields with: idField.
    fields := gLibrary g_list_append: fields with: humanIdField.
    fields := gLibrary g_list_append: fields with: titleField.
    fields := gLibrary g_list_append: fields with: typeField.
    fields := gLibrary g_list_append: fields with: descriptionField.
    fields := gLibrary g_list_append: fields with: textUnitIdsField.
    fields := gLibrary g_list_append: fields with: degreeField.
    ^ arrowLibrary garrow_schema_new: fields
]

{ #category : 'schema' }
MooseGraphRAGV2 >> prepareRelationshipsSchema [
    | strType intType floatType idField humanIdField sourceField targetField
      descriptionField weightField textUnitIdField lstType textUnitIdsField
      combinedDegreeField fields |
    strType := arrowLibrary garrow_string_data_type_new.
    intType := arrowLibrary garrow_int64_data_type_new.
    floatType := arrowLibrary garrow_float_data_type_new.
    idField := arrowLibrary garrow_field_new: 'id' dataType: strType.
    humanIdField := arrowLibrary garrow_field_new: 'human_readable_id' dataType: intType.
    sourceField := arrowLibrary garrow_field_new: 'source' dataType: strType.
    targetField := arrowLibrary garrow_field_new: 'target' dataType: strType.
    descriptionField := arrowLibrary garrow_field_new: 'description' dataType: strType.
    weightField := arrowLibrary garrow_field_new: 'weight' dataType: floatType.
    textUnitIdField := arrowLibrary garrow_field_new: 'text_unit_id' dataType: strType.
    lstType := arrowLibrary garrow_list_data_type_new: textUnitIdField.
    textUnitIdsField := arrowLibrary garrow_field_new: 'text_unit_ids' dataType: lstType.
    combinedDegreeField := arrowLibrary garrow_field_new: 'combined_degree' dataType: intType.
    fields := nil.
    fields := gLibrary g_list_append: fields with: idField.
    fields := gLibrary g_list_append: fields with: humanIdField.
    fields := gLibrary g_list_append: fields with: sourceField.
    fields := gLibrary g_list_append: fields with: targetField.
    fields := gLibrary g_list_append: fields with: descriptionField.
    fields := gLibrary g_list_append: fields with: weightField.
    fields := gLibrary g_list_append: fields with: textUnitIdsField.
    fields := gLibrary g_list_append: fields with: combinedDegreeField.
    ^ arrowLibrary garrow_schema_new: fields
]

{ #category : 'schema' }
MooseGraphRAGV2 >> prepareTextUnitsSchema [
    | strType intType idField humanIdField textField nTokensField documentIdField
      entityIdField entityLstType entityIdsField relIdField relLstType
      relIdsField fields |
    strType := arrowLibrary garrow_string_data_type_new.
    intType := arrowLibrary garrow_int64_data_type_new.
    idField := arrowLibrary garrow_field_new: 'id' dataType: strType.
    humanIdField := arrowLibrary garrow_field_new: 'human_readable_id' dataType: intType.
    textField := arrowLibrary garrow_field_new: 'text' dataType: strType.
    nTokensField := arrowLibrary garrow_field_new: 'n_tokens' dataType: intType.
    documentIdField := arrowLibrary garrow_field_new: 'document_id' dataType: strType.
    entityIdField := arrowLibrary garrow_field_new: 'entity_id' dataType: strType.
    entityLstType := arrowLibrary garrow_list_data_type_new: entityIdField.
    entityIdsField := arrowLibrary garrow_field_new: 'entity_ids' dataType: entityLstType.
    relIdField := arrowLibrary garrow_field_new: 'relationship_id' dataType: strType.
    relLstType := arrowLibrary garrow_list_data_type_new: relIdField.
    relIdsField := arrowLibrary garrow_field_new: 'relationships_ids' dataType: relLstType.
    fields := nil.
    fields := gLibrary g_list_append: fields with: idField.
    fields := gLibrary g_list_append: fields with: humanIdField.
    fields := gLibrary g_list_append: fields with: textField.
    fields := gLibrary g_list_append: fields with: nTokensField.
    fields := gLibrary g_list_append: fields with: documentIdField.
    fields := gLibrary g_list_append: fields with: entityIdsField.
    fields := gLibrary g_list_append: fields with: relIdsField.
    ^ arrowLibrary garrow_schema_new: fields
]

{ #category : 'private' }
MooseGraphRAGV2 >> propertyRelationshipRecords [

	| records |
	records := OrderedCollection new.
	self entitiesToExport do: [ :entity |
			entity metadescription allComplexProperties do: [ :property |
					(property isRelation and: [ property isDerived not ]) ifTrue: [
							| value targets |
							value := [ property getFrom: entity ]
								         on: Error
								         do: [ nil ].
							value isNil ifFalse: [
									targets := value isCollection
										           ifTrue: [ value asOrderedCollection ]
										           ifFalse: [ OrderedCollection with: value ].
									targets do: [ :target |
											(target isNil not and: [ target respondsTo: #mooseID ])
												ifTrue: [
														records add: {
																(entity mooseID printString , '-' , property name
																 , '-' , target mooseID printString).
																entity.
																target.
																(property name , ': '
																 , (property comment ifNil: [ '' ])).
																(self textUnitIdsFor: entity) } ] ] ] ] ] ].
	^ records
]

{ #category : 'private' }
MooseGraphRAGV2 >> relationshipIdsFor: entity [
    ^ entityRelationshipMap at: entity mooseID ifAbsent: [ OrderedCollection new ]
]

{ #category : 'private' }
MooseGraphRAGV2 >> relationshipRecords [
    | all byId |
    all := OrderedCollection new.
    all addAll: self propertyRelationshipRecords.
    all addAll: self invocationRelationshipRecords.
    byId := Dictionary new.
    all do: [ :record | byId at: record first put: record ].
    ^ byId values asOrderedCollection
]

{ #category : 'private' }
MooseGraphRAGV2 >> safeString: aValue [

	^ aValue
		ifNil: [ '' ]
		ifNotNil: [ aValue asString ]
]

{ #category : 'private' }
MooseGraphRAGV2 >> safeStringCollection: aCollection [

	| sanitized |
	sanitized := OrderedCollection new.
	(aCollection ifNil: [ #() ]) do: [ :each |
		each ifNotNil: [ sanitized add: (self safeString: each) ] ].
	^ sanitized
]

{ #category : 'accessing' }
MooseGraphRAGV2 >> textUnitEntities [
	"Entities (primarily methods) that have non-empty source text"

	^ (self model allWithSubTypesOfAny: self filteredFamixEntities)
		  reject: [ :entity | 
			  entity sourceText isEmpty ]
]

{ #category : 'private' }
MooseGraphRAGV2 >> textUnitIdsFor: entity [

	^ methodTextUnitMap at: entity mooseID ifPresent: [ :ids | OrderedCollection with: ids ] ifAbsent:  [ OrderedCollection new   ]

	
]

{ #category : 'exporting' }
MooseGraphRAGV2 >> writeTable: aTable schema: aSchema toFile: aFileName [
    | path writer |
    path := outputPath , '/' , aFileName.
    writer := parquetLibrary
        gparquet_arrow_file_writer_new_path: aSchema
        path: path
        writerProperties: nil
        error: nil.
    parquetLibrary
        gparquet_arrow_file_writer_write_table: writer
        table: aTable
        chunkSize: 10000
        error: nil.
    parquetLibrary gparquet_arrow_file_writer_close: writer error: nil
]
