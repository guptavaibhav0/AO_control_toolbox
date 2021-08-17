function w = logspace2(a,b,c)
w = logspace(log10(a),log10(b),c);
w(end) = b;
end
