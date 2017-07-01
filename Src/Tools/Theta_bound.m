function [ mean_theta, lb_theta, ub_theta ] = Theta_bound( x )
% THETA_BOUN
% Bound and start value for correlation parameter estimation
%
%   x (n by m matrix) is the input matrix of the dataset
%
% Syntax :
% [mean_theta,lb_theta,ub_theta]=Theta_bound_normal(x);

% Manhattan Distance between input points calculation
x_2 = permute(x',[3 1 2]);
dist(:,:)=sum(abs(bsxfun(@minus,x,x_2)),2); 
dist=triu(dist);
dist=reshape(dist,1,size(x,1)^2);
dist(dist==0)=[];

%% Heuristic rule for kriging correlation parameter estimation or gamma for RBF

lb_theta=min(dist);
ub_theta=max(dist);
mean_theta=mean(dist);

end

