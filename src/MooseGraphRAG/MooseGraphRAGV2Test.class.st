Class {
	#name : 'MooseGraphRAGV2Test',
	#superclass : 'TestCase',
	#instVars : [
		'model',
		'tmpPath'
	],
	#category : 'MooseGraphRAG-GraphRAGV2',
	#package : 'MooseGraphRAG',
	#tag : 'GraphRAGV2'
}

{ #category : 'helper' }
MooseGraphRAGV2Test >> buildSmallModel [
    "Create a minimal FamixJavaModel with one class, two methods with source, one attribute, and one invocation"
    | cls method1 method2 anchor1 anchor2 attr inv |
    model := FamixJavaModel new.
    model name: 'TestModel'.
    cls := FamixJavaClass new.
    cls name: 'TestClass'.
    model add: cls.

    method1 := FamixJavaMethod new.
    method1 name: 'caller'.
    method1 parentType: cls.
    anchor1 := FamixJavaSourceTextAnchor new.
    anchor1 source: 'public void caller() { callee(); }'.
    method1 sourceAnchor: anchor1.
    model add: method1.

    method2 := FamixJavaMethod new.
    method2 name: 'callee'.
    method2 parentType: cls.
    anchor2 := FamixJavaSourceTextAnchor new.
    anchor2 source: 'public void callee() { return; }'.
    method2 sourceAnchor: anchor2.
    model add: method2.

    attr := FamixJavaAttribute new.
    attr name: 'testField'.
    attr parentType: cls.
    model add: attr.

    inv := FamixJavaInvocation new.
    inv sender: method1.
    inv addCandidate: method2.
    model add: inv
]

{ #category : 'helper' }
MooseGraphRAGV2Test >> exporter [
    | v2 |
    v2 := MooseGraphRAGV2 new.
    v2 model: model.
    v2 exportTo: tmpPath.
    ^ v2
]

{ #category : 'running' }
MooseGraphRAGV2Test >> setUp [
    super setUp.
    self buildSmallModel.
    tmpPath := FileLocator temp fullName , '/moosegraphrag_test_' , DateAndTime now asUnixTime printString.
    tmpPath asFileReference ensureCreateDirectory
]

{ #category : 'running' }
MooseGraphRAGV2Test >> tearDown [
    super tearDown.
    tmpPath asFileReference ensureDeleteAll
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testEntitiesTableHasRightStructure [
    | exporter reader table |
    exporter := self exporter.
    reader := GParquetArrowFileReader on: tmpPath , '/entities.parquet' error: nil.
    table := reader readTableWithError: nil.
    self assert: table numberOfRows equals: 4.
    self assert: table numberOfColumns equals: 7
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testEntityTypeIsNormalized [
    | v2 entities types |
    v2 := MooseGraphRAGV2 new.
    v2 model: model.
    entities := v2 entitiesToExport.
    types := entities collect: [ :e | v2 normalizedTypeOf: e ].
    self assert: (types includes: 'class').
    self assert: (types includes: 'method').
    self assert: (types includes: 'attribute').
    self deny: (types anySatisfy: [ :t | t includesSubstring: 'Famix' ])
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testExportCreatesThreeFiles [
    | exporter files |
    exporter := self exporter.
    files := tmpPath asFileReference children collect: #basename.
    self assert: files size equals: 3.
    self assert: (files includes: 'entities.parquet').
    self assert: (files includes: 'text_units.parquet').
    self assert: (files includes: 'relationships.parquet')
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testRelationshipsContainsInvocation [
    | v2 records descriptions |
    v2 := MooseGraphRAGV2 new.
    v2 model: model.
    v2 computePrecomputedData.
    records := v2 relationshipRecords.
    self assert: records isNotEmpty.
    descriptions := records collect: [ :r | r fourth ].
    self assert: (descriptions includes: 'invokes')
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testRelationshipsTableIsEmpty [
    "Kept for backward compatibility name only; relationships are now expected with invocations"
    ^ self testRelationshipsContainsInvocation
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testTextUnitsTableHasRightStructure [
    | exporter reader table |
    exporter := self exporter.
    reader := GParquetArrowFileReader on: tmpPath , '/text_units.parquet' error: nil.
    table := reader readTableWithError: nil.
    self assert: table numberOfRows equals: 2.
    self assert: table numberOfColumns equals: 7
]
