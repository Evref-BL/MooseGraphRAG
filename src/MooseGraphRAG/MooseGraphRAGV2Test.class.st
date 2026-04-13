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
    "Create a minimal FamixJavaModel with one class, one method with source, one attribute"
    | cls method anchor attr |
    model := FamixJavaModel new.
    model name: 'TestModel'.
    cls := FamixJavaClass new. cls name: 'TestClass'. model add: cls.
    method := FamixJavaMethod new. method name: 'testMethod'. method parentType: cls.
    anchor := FamixJavaSourceTextAnchor new.
    anchor source: 'public void testMethod() { return 42; }'.
    method sourceAnchor: anchor.
    model add: method.
    attr := FamixJavaAttribute new. attr name: 'testField'. attr parentType: cls.
    model add: attr
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
    self assert: table numberOfRows equals: 3.
    self assert: table numberOfColumns equals: 7
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
MooseGraphRAGV2Test >> testRelationshipsTableIsEmpty [
    | exporter reader table |
    exporter := self exporter.
    reader := GParquetArrowFileReader on: tmpPath , '/relationships.parquet' error: nil.
    table := reader readTableWithError: nil.
    self assert: table numberOfRows equals: 0
]

{ #category : 'test_export' }
MooseGraphRAGV2Test >> testTextUnitsTableHasRightStructure [
    | exporter reader table |
    exporter := self exporter.
    reader := GParquetArrowFileReader on: tmpPath , '/text_units.parquet' error: nil.
    table := reader readTableWithError: nil.
    self assert: table numberOfRows equals: 1.
    self assert: table numberOfColumns equals: 7
]
