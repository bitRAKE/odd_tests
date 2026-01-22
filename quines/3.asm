virtual
A::db 'virtual!A::db "!load a:$ from 0!end virtual!repeat sizeof A!load b:1 from A:%-1!if b=34!db 39,a,39!else if b=33!db 10!else!db b!end if!end repeat'
load a:$ from 0
end virtual
repeat sizeof A
load b:1 from A:%-1
if b=34
db 39,a,39
else if b=33
db 10
else
db b
end if
end repeat