function [ y_pred, power ] = Predict( obj, x_eval )
% PREDICT 
%   Predict the output value at new input points
%   - power is a measure of prediction error (from Gutmann)
%
%   Syntax examples :
%       y_pred=obj.Predict(x_eval);
%       [y_pred, power]=obj.Predict(x_eval);

% Superclass method
x_eval_scaled = obj.Predict@Metamodel( x_eval );

n_eval = size( x_eval, 1 );

diff_pred_squared=abs(bsxfun(@minus,permute(x_eval_scaled,[3 2 1]),obj.x_train)).^2;

corr_mat_pred = feval( obj.corr, obj, diff_pred_squared, log10(obj.hyp_corr));

switch obj.corr
    
    case {'Corrgauss','Corrinvmultiquadric','Corrmatern32','Corrmatern52'}
        f_mat_pred = [];
    case {'Corrlinear','Corrmultiquadric'}
        f_mat_pred = ones(n_eval,1);
    case {'Corrcubic','Corrthinplatespline'}
        f_mat_pred = [ ones(n_eval,1) x_eval_scaled];
end

if isempty(f_mat_pred)
    
    y_pred = corr_mat_pred' * obj.beta;
    
else
    
    y_pred = corr_mat_pred' * obj.beta + f_mat_pred * obj.alpha;
    
end

if nargout > 1
    
    phi_zero = feval( obj.corr, obj, 0, log10(obj.hyp_corr));
    warning('off','MATLAB:singularMatrix')
    warning('off','MATLAB:nearlySingularMatrix')
    power_1 =  [corr_mat_pred' f_mat_pred] * ...
        ([obj.corr_mat obj.f_mat ; obj.f_mat' obj.zero_mat] \...
        [corr_mat_pred' f_mat_pred]');
    warning('on','MATLAB:singularMatrix')
    warning('on','MATLAB:nearlySingularMatrix')
    
    power = sqrt( abs( phi_zero - diag(power_1) ) );
    
end

end

