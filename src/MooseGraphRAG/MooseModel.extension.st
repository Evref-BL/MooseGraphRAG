Extension { #name : 'MooseModel' }

{ #category : '*MooseGraphRAG' }
MooseModel >> metadescription [

	^ self metadescriptionFor: self class
]

{ #category : '*MooseGraphRAG' }
MooseModel >> metadescriptionFor: class [

	^ self metamodel fmTypeOf: class instanceSide
]
