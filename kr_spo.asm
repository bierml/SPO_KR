;Курсовой проект по СПО
;Вариант: 6
;Выполнил: Винокуров Родион
;Группа: А-12-19
;Отображение монохромного (1 бит на точку) файла BMP на экране (рекомедуемый видеорежим - 256 цветов)
.model small
.stack 100h ;256 байт на стек
.data
	;сообщения, выдаваемые на экран

	entmsg db 'Enter file name: $' ;ввод имени файла
	errmsg db 10,13,'File opening error!',10,13,'$' ;ошибка открытия файла
	clerr db 10,13,'File closing error!',10,13,'$'  ;ошибка закрытия файла
	forerr db 10,13,'The opened file is not a BMP file!',10,13,'$'	;ошибка формата файла
	monerr db 10,13,'The opened file is not monochrome!',10,13,'$'	;ошибка формата BMP файла 

	;параметры для ввода имени входного файла

	string db 255,255,255 dup (0)	;строка для хранения имени файла
	len db 0			;длина строки с именем файла
	
	;дескриптор файла

	descr dw ?
	
	;служебные переменные
	
	buff db 40 dup (0)	;буфер для одной строки изображения (320 пикс=320 бит=40 байт)
	oldMode db ?		;хранит номер изначального видеорежима
	filetype dw ?		;первые два байта открытого файла (4d42 указывает на BMP файл)
	bfOffBits dd ?		;смещение графических данных файла
	biWidth dd ?		;ширина изображения 
	biHeight dd ?		;высота изображения 
	biBitCount dw ?		;количество бит на точку (должен быть равен 1!)
	bytesinstr dw ?		;смещение в байтах для перехода к следующей строке изображения
	bytesdrawing dw ?	;количество байт, которые будут прочитаны в буфер и отображены на экране
	yres dw ?		;координата по вертикали самой верхней строки изображения (отсчет идет с 200 в сторону уменьшения)
	
	
.code	

;процедура для рисования строки из буфера buff
;row - номер строки

drawstr proc near
	ARG row
	push bp
	mov bp,sp
	
	mov ax,row
	mov bx,0	;столбец, в котором находится текущий пиксель
	mov dh,80h	;начальное значение маски (единица в самой левой позиции)
	mov bp,0	;смещение читаемого байта внутри буфера
	
	;пусть dl - очередной байт буфера, dh - маска
	@@cycle:
		inc bx
		lea si,buff	;загружаем в si адрес начала буфера
		add si,bp	;прибавляем смещение
		mov dl,[si]
		and dl,dh	;накладываем маску на прочитанный байт
		cmp dl,0	
		jz @@sk1_	;если в рассматриваемом бите 1 - вызываем drawpix
		
		push dx
		push di
		push bx
		push ax
		call drawpix
		pop ax
		pop bx
		pop di
		pop dx
		
		@@sk1_:		
		ror dh,1	;сдвигаем единицу в маске на одну позицию вправо
		jnc @@cycle	;перенос=>байт прочитан, переход к следующему байту
		inc bp		
		cmp bp,40	
	jnz @@cycle
	pop bp
	retn
drawstr endp

;нарисовать точку
;row - строка, col - столбец
	
drawpix proc near
	ARG row,col
	push bp
	mov bp,sp
	
	;di=320*(row-1)+col-1 - смещение пикселя от начала видеобуфера
	mov ax,row
	mov bx,col
	dec ax
	mov dx,320
	mul dx
	add ax,bx
	mov di,ax	
	dec di			
	
	mov byte ptr es:[di],1	;помещаем единицу в видеобуфер по нужному смещению
	
	pop bp
	retn	
drawpix endp

start:
	
	;инициализация сегментных регистров
	mov ax,@data
	mov ds,ax
	mov es,ax
	
	;вывод сообщения о вводе имени файла
	mov dx,offset entmsg
	mov ah,09h
	int 21h
	
	;ожидание ввода строки
	mov ah,0Ah
	mov dx,offset string
	int 21h
	
	
	
	;сохраняем в len текущую длину строки
	mov si,offset string
	inc si		;помещаем в si смещение второго байта строки (текущая длина)
	mov al,[si]
	mov len,al
	
	;обнуляем последний символ строки
	mov si,offset string 
	mov ax,si
	add al,len
	mov si,ax
	add si,2	;первые два символа: первоначальная и текущая длина строки
	mov byte ptr [si],0
	
	;открытие файла 
	add dx,2	;пропускаем два первых символа
	xor al,al	;режим только для чтения
	mov ah,3dh
	int 21h

	jnc fexist_
	;вывод сообщения об ошибке при открытии файла
	mov dx,offset errmsg
	mov ah,09h
	int 21h
	
	;завершение работы программы
	mov ax, 4C00h
	int 21h

	fexist_:
	;читаем первые два байта из файла
	mov descr,ax		;сохраняем дескриптор файла в descr
	mov ah,3fh
	mov bx,descr
	mov cx,2
	mov dx,offset filetype	;читаем тип файла в filetype
	int 21h
	
	;файла формата BMP?
	mov ax,[filetype]
	cmp ax,4d42h
	jz fisbmp_
	
	;выводим сообщение об ошибке формата
	mov dx,offset forerr
	mov ah,09h
	int 21h
	
	;пытаемся закрыть файл
	mov ah,3eh
	mov bx,descr
	int 21h
	
	;не удалось закрыть файл - сообщение об ошибке
	jnc noclerr
	mov dx,offset clerr
	mov ah,09h
	int 21h
	
	;завершение работы программы
	noclerr:
	mov ax, 4C00h
	int 21h
	
	fisbmp_:
	;переходим к позиции в файле 0Ah (bfOffBits)
	mov ax,4200h
	mov bx,descr
	xor cx,cx
	mov dx,0Ah
	int 21h
	
	;читаем значение из файла в bfOffBits
	mov ah,3fh
	mov cx,4
	mov dx,offset bfOffBits
	int 21h
	
	;переходим к позиции в файле 12h (biWidth)
	mov ax,4200h
	xor cx,cx
	mov dx,12h
	int 21h
	
	;читаем значение из файла в biWidth
	mov ah,3fh
	mov cx,4
	mov dx,offset biWidth
	int 21h
	
	;переходим к позиции в файле 16h (biHeight)
	mov ax,4200h
	xor cx,cx
	mov dx,16h
	int 21h
	
	;читаем значение из файла в biHeight
	mov ah,3fh
	mov cx,4
	mov dx,offset biHeight
	int 21h
	
	;находим yres 
	lea si,biHeight
	mov ax,[si]
	mov yres,ax
	cmp ax,200	;сравниваем biHeight с 200
	jc stheight
	mov yres,200	;если biHeight>=200, то yres=200, иначе yres=biHeight
	stheight: 
	mov ax,200
	sub ax,yres	;yres:=200-yres (т.к. строки в файле BMP расположены снизу вверх)
	mov yres,ax
	
	;переходим к позиции в файле 1Ch (biBitCount)
	mov ax,4200h
	xor cx,cx
	mov dx,1Ch
	int 21h
	
	;читаем значение из файла в biBitCount
	mov ah,3fh
	mov cx,2
	mov dx,offset biBitCount
	int 21h
	
	;файл монохромный? (biBitCount=1?)
	mov ax,biBitCount
	cmp ax,1
	jz fismon_
	
	;файл не монохромный=>сообщение об ошибке
	mov dx,offset monerr
	mov ah,09h
	int 21h
	
	;пытаемся закрыть файл
	mov ah,3eh
	mov bx,descr
	int 21h
	
	;не удалось закрыть файл=>выводим сообщение об ошибке
	jnc noclerr__
	mov dx,offset clerr
	mov ah,09h
	int 21h
	
	;завершение работы программы
	noclerr__:
	mov ax, 4C00h
	int 21h
	
	fismon_:
	
	
	;устанавливаем граф.режим
	mov ah,0Fh
	int 10h		;определим текущий граф. режим
	mov oldMode,al	;сохраним его в oldMode
	mov ah,00h
	mov al,13h	;видеорежим 13h (320*200,256 цветов)
	int 10h
	push 0A000h	;сегментный адрес видеобуфера
	pop es		;es=0A000h
	
	
	
	;выбираем индекс 0 в порте выбора палитры (3c8h)
	mov dx,3c8h
	mov al,0
	out dx,al
	
	;значение красного цвета
	mov dx,3c9h	;установка цвета производится через порт 3c9h
	mov al,0
	out dx,al
	
	;значение зеленого цвета
	mov al,0
	out dx,al
	
	;значение синего цвета
	mov al,0
	out dx,al
	
	;выбираем индекс 1 в порте выбора палитры (3c8h)
	mov dx,3c8h
	mov al,1
	out dx,al
	
	;значение красного цвета
	mov dx,3c9h	;установка цвета производится через порт 3c9h
	mov al,63
	out dx,al
	
	;значение зеленого цвета
	mov al,63
	out dx,al
	
	;значение синего цвета
	mov al,63
	out dx,al
	
	;расчет длины строки изображения в байтах
	lea si,biWidth
	mov ax,[si]
	mov dx,[si+2]
	mov bx,32
	div bx			;ax=biWidth div 32,dx=biWidth mod 32
	cmp dx,0
	jz noalign_
	inc ax			;biWidth не кратно 32=>прибавляем 1 к ax (длина округляется в большую сторону)
	noalign_:
	mov bx,4
	mul bx			;переводим величину в байты
	mov bytesinstr,ax	;bytesinstr - длина строки в байтах с учетом выравнивания	
	
	;находим число выводимых на экран в одной строке байт 
	mov bytesdrawing,ax
	cmp ax,40
	jc lwidth	;если bytesinstr>=40, то bytesdrawing=40,иначе bytesdrawing=bytesinstr
	mov bytesdrawing,40
	lwidth:
	
	;bytesinstr:=bytesinstr-bytesdrawing (при чтении указатель будет смещаться на bytesdrawing байт)
	mov ax,bytesdrawing
	sub bytesinstr,ax	

	;пусть cx - координата строки изображения
	mov cx,200
	push cx		;сохраняем координату строки в стеке
	
	;переходим к графическим данным изображения
	mov ax,4200h
	mov bx,descr
	lea si,bfOffBits
	mov cx,[si+2]
	mov dx,[si]
	int 21h
	
	;читаем строку в буфер buff
	mov ah,3fh
	mov cx,bytesdrawing
	mov dx,offset buff
	int 21h
	
	
	call drawstr	;вывод строки изображения на экран

	pop cx		;восстанавливаем cx
	dec cx		;переходим к следующей строке изображения
	
	DRAWSTRING:
	push cx		;сохраняем координату строки в стеке

	;сдвигаемся на bytesinstr байт от текущей позиции
	mov ax,4201h
	mov bx,descr
	mov cx,0
	mov dx,bytesinstr
	int 21h
	
	;читаем строку в буфер buff
	mov ah,3fh
	mov cx,bytesdrawing
	mov dx,offset buff
	int 21h
	
	call drawstr	;вывод строки изображения на экран
	pop cx		;восстанавливаем cx
	dec cx		;переходим к следующей строке изображения
	cmp cx,yres	;достигнута последняя строка изображения?
	jnz DRAWSTRING
	
	;ожидание ввода символа для задержки изображения на экране
	mov ah,08h	
	int 21h
	
	;восстановим старый видеорежим
	mov ah,0
	mov al,oldMode
	int 10h
	
	;пытаемся закрыть файл
	mov ah,3eh
	mov bx,descr
	int 21h
	
	;не удалось закрыть файл - выводим сообщение об ошибке
	jnc noclerr_
	mov dx,offset clerr
	mov ah,09h
	int 21h

	;завершение работы программы
	noclerr_:
	mov ax, 4C00h
	int 21h
end start
