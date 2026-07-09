Extension { #name : 'MooseEntity' }

{ #category : '*MooseGraphRAG' }
MooseEntity >> metadescription [
	^ (self metamodel fmTypeOf: self class instanceSide)
]
