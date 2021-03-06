using GR

mwidth, mheight, width, height = GR.inqdspsize()

w = 800
h = 600

setcolorrep(1, 1.0, 1.0, 1.0)
setcolorrep(2, 0.0, 0.0, 0.0)
setlinecolorind(2)
setlinewidth(1)
setlinetype(GR.LINETYPE_SOLID)
setfillcolorind(2)
setfillintstyle(GR.INTSTYLE_SOLID)

while true
    clearws()

    #w = 400 + round(Int, rand() * 200)
    #h = 400 + round(Int, rand() * 200)
    if w >= h
        ratio = float(h) / w
        msize = mwidth * w / width
        GR.setwsviewport(0, msize, 0, msize * ratio)
        GR.setwswindow(0, 1, 0, ratio)
        setviewport(0, 1, 0, ratio)
    else
        ratio = float(w) / h
        msize = mheight * h / height
        GR.setwsviewport(0, msize * ratio, 0, msize)
        GR.setwswindow(0, ratio, 0, 1)
        setviewport(0, ratio, 0, 1)
    end

    setwindow(1, w, 1, h)

    #drawrect(1, w, 1, h)
    fillrect(1, w, 1, h)
    #polyline([1,w],[1,h])
    #polyline([1,w],[h,1])
    text(0.05, 0.05, "$w x $h")

    updatews()
    sleep(0.5)
end
