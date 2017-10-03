function func_val = Meta_int1(obj, x )
%META_INT1 Summary of this function goes here
% Use for 1D integration with @integral

[n1,n2]=size(x);

x = reshape(x,n1*n2,1);

if obj.m_y >= 1
    [~,func_val] = obj.meta_y.Predict(x);
end
if obj.m_g >= 1
    [~,func_val] = obj.meta_g.Predict(x);
end
          
func_val = reshape(func_val,n1,n2);

end

