Extension { #name : 'MooseModel' }

{ #category : '*MooseGraphRAG' }
MooseModel >> metadescriptionFor: class [

	^ self metamodel fmTypeOf: class instanceSide
]
