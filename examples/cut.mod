% The actual structure of propositions does not matter, but
% we use this predicate as a measure for induction.
prop top.
prop bot.
prop (p X).                             % an arbitrary unary predicate P
prop (and A B) :- prop A, prop B.
prop (or A B) :- prop A, prop B.
prop (imp A B) :- prop A, prop B.
prop (all A) :- pi x\ prop (A x).
prop (ex A) :- pi x\ prop (A x).


conc A :- hyp A.                                             % init
conc top.                                                    % topR
conc C :- hyp bot.                                           % botL

conc (and A B) :- conc A, conc B.                            % andR
conc C :- hyp (and A B), hyp A => hyp B => conc C.           % andL

conc (or A B) :- conc A.                                     % orR_1
conc (or A B) :- conc B.                                     % orR_2
conc C :- hyp (or A B), hyp A => conc C, hyp B => conc C.    % orL

conc (imp A B) :- hyp A => conc B.                           % impR
conc C :- hyp (imp A B), conc A, hyp B => conc C.            % impL

conc (all A) :- pi x\ conc (A x).                            % allR
conc C :- hyp (all A), hyp (A T) => conc C.                  % allL

conc (ex A) :- conc (A T).                                   % exR
conc C :- hyp (ex A), pi x\ hyp (A x) => conc C.             % exL
