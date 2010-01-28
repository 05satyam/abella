open OUnit
open Test_helper
open Term
open Term.Notations
open Metaterm
open Tactics
open Unify
open Extensions

let assert_object_cut ~cut ~using ~expect =
  match freshen cut, freshen using with
    | Obj(Seq(ctx1, g1), _), Obj(Seq(ctx2, g2), _) ->
        let actx, ag = object_cut (ctx1, g1) (ctx2, g2) in
        let actual = Obj(Seq(actx, ag), Irrelevant) in
          assert_pprint_equal expect actual
    | _ -> assert false

let object_cut_tests =
  "Object Cut" >:::
    [
      "Simple" >::
        (fun () ->
           assert_object_cut
             ~cut:    "{a |- b}"
             ~using:  "{a}"
             ~expect: "{b}"
        );

      "Contexts should be merged" >::
        (fun () ->
           assert_object_cut
             ~cut:    "{a, b |- c}"
             ~using:  "{d |- b}"
             ~expect: "{d, a |- c}"
        );

      "Context should be normalized" >::
        (fun () ->
           assert_object_cut
             ~cut:    "{a, b, c |- d}"
             ~using:  "{a, c |- b}"
             ~expect: "{a, c |- d}"
        );

      "Should fail on useless cut" >::
        (fun () ->
           assert_raises (Failure "Needless use of cut")
             (fun () ->
                assert_object_cut
                  ~cut:    "{a |- b}"
                  ~using:  "{c}"
                  ~expect: ""
             )
        );

      "Should fail if tails don't match" >::
        (fun () ->
           assert_raises (Failure "Cannot merge contexts")
             (fun () ->
                assert_object_cut
                  ~cut:    "{L, a |- b}"
                  ~using:  "{K |- a}"
                  ~expect: ""
             )
        );
    ]


let assert_object_inst ~on ~inst ~using ~expect =
  let on = parse_metaterm on in
  let using = uvar Eigen using 0 in
  let actual = object_inst on inst using in
    assert_pprint_equal expect actual

let object_instantiation_tests =
  "Object Instantiation" >:::
    [
      "Simple" >::
        (fun () ->
           assert_object_inst
             ~on:"{eq n1 t2}"
             ~inst:"n1"
             ~using:"t1"
             ~expect:"{eq t1 t2}"
        );

      "Should fail if nominal is not found" >::
        (fun () ->
           assert_raises (Failure "Did not find n2")
             (fun () ->
                assert_object_inst
                  ~on:"{eq n1 n1}"
                  ~inst:"n2"
                  ~using:"dummy"
                  ~expect:""
             )
        );

      "Should only work on nominals" >::
        (fun () ->
           assert_raises (Failure "Did not find A")
             (fun () ->
                assert_object_inst
                  ~on:"{eq t1 t2}"
                  ~inst:"A"
                  ~using:"dummy"
                  ~expect:""
             )
        );

      "Can increase proof height when target type is o" >::
        (fun () ->
           let on = parse_metaterm "{n1 t1}*" in
           let using = parse_term "x\\ p1 x => p2 x" (tyarrow [ity] oty) in
           let actual = object_inst on "n1" using in
             assert_pprint_equal "{p1 t1 => p2 t1}" actual
        ) ;

    ]

let apply_tests =
  "Apply" >:::
    [
      "Normal" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B} -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Properly restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}* -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}*" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Needlessly restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B} -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}*" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Improperly restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}* -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Improperly restricted (2)" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}* -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}@" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Properly double restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}@ -> {typeof A C}** -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}@" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}**" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Improperly double restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}@ -> {typeof A C}** -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}@" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}@@" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Improperly double restricted (2)" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}@ -> {typeof A C}** -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}**" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Properly restricted on predicate" >::
        (fun () ->
           let h0 = freshen "forall A, foo A * -> bar A" in
           let h1 = freshen "foo A *" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "bar A" t) ;

      "Improperly restricted on predicate" >::
        (fun () ->
           let h0 = freshen "forall A, foo A * -> bar A" in
           let h1 = freshen "foo A @" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1])) ;

      "Unification failure" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B} -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{eval (abs S) (abs S)}" in
             try
               let _ = apply h0 [Some h1; Some h2] in
                 assert_failure "Expected constant clash"
             with
               | UnifyFailure(ConstClash _) -> ());

      "With contexts" >::
        (fun () ->
           let h0 = freshen
             ("forall E A C, {E, hyp A |- conc C} -> " ^
                "{E |- conc A} -> {E |- conc C}") in
           let h1 = freshen "{L, hyp A, hyp B1, hyp B2 |- conc C}" in
           let h2 = freshen "{L |- conc A}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{L, hyp B1, hyp B2 |- conc C}" t) ;

      "On non-object" >::
        (fun () ->
           let h0 = freshen "forall A, foo A -> bar A" in
           let h1 = freshen "foo B" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "bar B" t) ;

      "On arrow" >::
        (fun () ->
           let h0 = freshen "forall A, (forall B, foo A -> bar B) -> baz A" in
           let h1 = freshen "forall B, foo C -> bar B" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "baz C" t) ;

      "With nabla" >::
        (fun () ->
           let h0 = freshen "forall B, nabla x, rel1 x (B x) -> rel2 t1 (iabs B)" in
           let h1 = freshen "rel1 n1 (D n1)" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "rel2 t1 (iabs (x1\\D x1))" t) ;

      "With multiple nablas" >::
        (fun () ->
           let h0 =
             freshen "forall A B, nabla x y,
                        rel1 (iapp x y) (iapp (A x) (B y)) ->
                          rel2 (iabs A) (iabs B)"
           in
           let h1 = freshen "rel1 (iapp n1 n2) (iapp (C n1) (D n2))" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal
               "rel2 (iabs (x1\\C x1)) (iabs (x1\\D x1))"
               t) ;

      "With vacuous nabla" >::
        (fun () ->
           let h0 = freshen "forall A B, nabla x, rel1 (A x) (B x) -> rel2 (iabs A) (iabs B)" in
           let h1 = freshen "rel1 C D" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "rel2 (iabs (x1\\C)) (iabs (x1\\D))" t) ;

      "Absent argument should produce corresponding obligation" >::
        (fun () ->
           let h0 = freshen "forall L, foo L -> bar L -> false" in
           let h1 = freshen "bar K" in
           let _, obligations = apply h0 [None; Some h1] in
             match obligations with
               | [term] ->
                   assert_pprint_equal "foo K" term
               | _ -> assert_failure
                   ("Expected one obligation but found " ^
                      (string_of_int (List.length obligations)))) ;

      "Instantiate should not allow existing nominal" >::
        (fun () ->
           let h = freshen "nabla x, rel1 x n1" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", nominal_var "n1" ity)]
               ));

      "Instantiate should not allow soon to be existing nominal" >::
        (fun () ->
           let h = freshen "forall E, nabla x, rel1 E x" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", nominal_var "n1" ity);
                                       ("E", nominal_var "n1" ity)]
               ));

      "Instantiate should not allow two identical nominals" >::
        (fun () ->
           let h = freshen "nabla x y, rel1 x y" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", nominal_var "n1" ity);
                                       ("y", nominal_var "n1" ity)]
               ));

      "Instantiate should allow distinct nominals" >::
        (fun () ->
           let h = freshen "nabla x y, rel1 x y" in
           let (t, _) = instantiate_withs h [("x", nominal_var "n1" ity);
                                             ("y", nominal_var "n2" ity)] in
             assert_pprint_equal "rel1 n1 n2" t);

      "Instantiate should not allow non-nominal for nabla" >::
        (fun () ->
           let h = freshen "nabla x, foo x" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", const "A" ity)]
               ));

      "Apply with no arguments" >::
        (fun () ->
           let h = freshen "forall E, foo E" in
           let a = const "a" ity in
           let (t, _) = apply_with h [] [("E", a)] in
             assert_pprint_equal "foo a" t);

      "Apply with no arguments should contain logic variables" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A B" in
           let a = const "a" ity in
           let (t, _) = apply_with h [] [("A", a)] in
           let logic_vars = metaterm_vars_alist Logic t in
             assert_bool "Should contain logic variable(s)"
               (List.length logic_vars > 0));
    ]

let backchain_tests =
  "Backchain" >:::
    [
      "Normal" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A t1 -> rel2 B t2 -> rel3 A B" in
           let g = freshen "rel3 t3 t4" in
             match backchain h g with
               | [h1; h2] ->
                   assert_pprint_equal "rel1 t3 t1" h1 ;
                   assert_pprint_equal "rel2 t4 t2" h2
               | hs ->
                   assert_failure
                     ("Expected 2 obligations but found " ^
                        (string_of_int (List.length hs)))) ;

      "Properly restricted" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A t1 -> rel2 B t2 -> rel3 A B +" in
           let g = freshen "rel3 t3 t4 +" in
             match backchain h g with
               | [h1; h2] ->
                   assert_pprint_equal "rel1 t3 t1" h1 ;
                   assert_pprint_equal "rel2 t4 t2" h2
               | hs ->
                   assert_failure
                     ("Expected 2 obligations but found " ^
                        (string_of_int (List.length hs)))) ;

      "Needlessly restricted" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A t1 -> rel2 B t2 -> rel3 A B" in
           let g = freshen "rel3 t3 t4 +" in
             match backchain h g with
               | [h1; h2] ->
                   assert_pprint_equal "rel1 t3 t1" h1 ;
                   assert_pprint_equal "rel2 t4 t2" h2
               | hs ->
                   assert_failure
                     ("Expected 2 obligations but found " ^
                        (string_of_int (List.length hs)))) ;

      "Inductively restricted" >::
        (fun () ->
           let h = freshen
             "forall A B, rel1 A t1 * -> rel2 B t2 @ -> rel3 A B"
           in
           let g = freshen "rel3 t3 t4" in
             match backchain h g with
               | [h1; h2] ->
                   assert_pprint_equal "rel1 t3 t1 *" h1 ;
                   assert_pprint_equal "rel2 t4 t2 @" h2
               | hs ->
                   assert_failure
                     ("Expected 2 obligations but found " ^
                        (string_of_int (List.length hs)))) ;

      "Improperly restricted" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A t1 -> rel2 B t2 -> rel3 A B +" in
           let g = freshen "rel3 t3 t4" in
             assert_raises (Failure "Coinductive restriction violated")
               (fun () -> backchain h g)) ;

      "Improperly restricted (2)" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A t1 -> rel2 B t2 -> rel3 A B +" in
           let g = freshen "rel3 t3 t4 #" in
             assert_raises (Failure "Coinductive restriction violated")
               (fun () -> backchain h g)) ;

      "Improperly restricted (3)" >::
        (fun () ->
           let h = freshen "forall A B, rel1 A t1 -> rel2 B t2 -> rel3 A B +" in
           let g = freshen "rel3 t3 t4 ++" in
             assert_raises (Failure "Coinductive restriction violated")
               (fun () -> backchain h g)) ;

      "With contexts" >::
        (fun () ->
           let h = freshen
             "forall A B L, ctx L -> {L |- eq A B}"
           in
           let g = freshen "{L, eq t1 t2 |- eq t3 t4}" in
             match backchain h g with
               | [h1] ->
                   assert_pprint_equal "ctx (eq t1 t2 :: L)" h1 ;
               | hs ->
                   assert_failure
                     ("Expected 1 obligation but found " ^
                        (string_of_int (List.length hs)))) ;

      "With empty contexts" >::
        (fun () ->
           let h = freshen
             "forall A B, {pr A B} -> {eq A B}"
           in
           let g = freshen "{eq t1 t2}" in
             match backchain h g with
               | [h1] ->
                   assert_pprint_equal "{pr t1 t2}" h1 ;
               | hs ->
                   assert_failure
                     ("Expected 1 obligation but found " ^
                        (string_of_int (List.length hs)))) ;

      "With bad contexts" >::
        (fun () ->
           let h = freshen
             "forall A B L, ctx L -> {L, eq t1 t2 |- eq A B}"
           in
           let g = freshen "{L |- eq t3 t4}" in
             assert_raises_any
               (fun () -> backchain h g)) ;

    ]

let assert_expected_cases n cases =
  assert_failure (Printf.sprintf "Expected %d case(s) but found %d case(s)"
                    n (List.length cases))

let case ?used ?(clauses=[]) ?(defs=[]) ?(mutual=[])
    ?(global_support=[]) metaterm =
  let used =
    match used with
      | None -> metaterm_vars_alist Eigen metaterm
      | Some used -> used
  in
    case ~used ~clauses ~defs ~mutual ~global_support metaterm

let case_tests =
  "Case" >:::
    [
      "Normal" >::
        (fun () ->
           let term = freshen "{eval A B}" in
             match case ~clauses:eval_clauses term with
               | [case1; case2] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "{eval (abs R) (abs R)}" term ;
                   assert_bool "R should be flagged as used"
                     (List.mem "R" (List.map fst case1.new_vars)) ;

                   set_bind_state case2.bind_state ;
                   assert_pprint_equal "{eval (app M N) B}" term ;
                   begin match case2.new_hyps with
                     | [h1; h2] ->
                         assert_pprint_equal "{eval M (abs R)}" h1 ;
                         assert_pprint_equal "{eval (R N) B}" h2 ;
                     | _ -> assert_failure "Expected 2 new hypotheses"
                   end ;
                   assert_bool "R should be flagged as used"
                     (List.mem "R" (List.map fst case2.new_vars)) ;
                   assert_bool "M should be flagged as used"
                     (List.mem "M" (List.map fst case2.new_vars)) ;
                   assert_bool "N should be flagged as used"
                     (List.mem "N" (List.map fst case2.new_vars))
               | cases -> assert_expected_cases 2 cases) ;

      "Restriction should become smaller" >::
        (fun () ->
           let term = freshen "{p1 A}@" in
           let clauses = parse_clauses "p1 X :- p2 X." in
             match case ~clauses term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "{p2 A}*" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction on predicates should become smaller" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := foo X." in
           let mutual = ["foo"] in
             match case ~defs ~mutual term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "foo A *" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction should descend under binders" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := forall (Y:i), foo X." in
           let mutual = ["foo"] in
             match case ~defs ~mutual term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "forall Y, foo A *" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction should descend only under the right of arrows" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := foo X -> foo X." in
           let mutual = ["foo"] in
             match case ~defs ~mutual term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "foo A -> foo A *" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction should only apply to matching predicates" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := foo X \\/ bar X." in
           let mutual = ["foo"] in
             match case ~defs ~mutual term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "foo A * \\/ bar A" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "On OR" >::
        (fun () ->
           let term = freshen "{a} \\/ {b}" in
             match case term with
               | [{new_hyps=[hyp1]} ; {new_hyps=[hyp2]}] ->
                   assert_pprint_equal "{a}" hyp1 ;
                   assert_pprint_equal "{b}" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On multiple OR" >::
        (fun () ->
           let term = freshen "{a} \\/ {b} \\/ {c}" in
             match case term with
               | [{new_hyps=[hyp1]} ; {new_hyps=[hyp2]} ; {new_hyps=[hyp3]}] ->
                   assert_pprint_equal "{a}" hyp1 ;
                   assert_pprint_equal "{b}" hyp2 ;
                   assert_pprint_equal "{c}" hyp3 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "OR branches should not share unifiers" >::
        (fun () ->
           let term = freshen "A = B \\/ rel1 A B" in
             match case term with
               | [{new_hyps=[]} ; {new_hyps=[hyp]}] ->
                   assert_pprint_equal "rel1 A B" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On AND" >::
        (fun () ->
           let term = freshen "{a} /\\ {b}" in
             match case term with
               | [{new_hyps=[hyp1;hyp2]}] ->
                   assert_pprint_equal "{a}" hyp1 ;
                   assert_pprint_equal "{b}" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On multiple AND" >::
        (fun () ->
           let term = freshen "{a} /\\ {b} /\\ {c}" in
             match case term with
               | [{new_hyps=[hyp1;hyp2;hyp3]}] ->
                   assert_pprint_equal "{a}" hyp1 ;
                   assert_pprint_equal "{b}" hyp2 ;
                   assert_pprint_equal "{c}" hyp3 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On exists" >::
        (fun () ->
           let term = freshen "exists A B, rel1 A B" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"; "B"] var_names ;
                     assert_pprint_equal "rel1 A B" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nested exists, AND" >::
        (fun () ->
           let term = freshen "exists A B, foo A /\\ bar B" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp1; hyp2]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"; "B"] var_names ;
                     assert_pprint_equal "foo A" hyp1 ;
                     assert_pprint_equal "bar B" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nested AND, exists" >::
        (fun () ->
           let term = freshen "{a} /\\ exists B, bar B" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp1; hyp2]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["B"] var_names ;
                     assert_pprint_equal "{a}" hyp1 ;
                     assert_pprint_equal "bar B" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nabla" >::
        (fun () ->
           let term = freshen "nabla x, foo x" in
           let used = [] in
             match case ~used term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "foo n1" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On multiple nablas" >::
        (fun () ->
           let term = freshen "nabla x y, rel1 x y" in
           let used = [] in
             match case ~used term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "rel1 n1 n2" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nested nabla, exists" >::
        (fun () ->
           let term = freshen "nabla x, exists A, rel1 x A" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"] var_names ;
                     assert_pprint_equal "rel1 n1 (A n1)" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nabla with n1 used" >::
        (fun () ->
           let term = freshen "nabla x, rel1 n1 x" in
           let used = [] in
             match case ~used term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "rel1 n1 n2" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "Should backchain using context" >::
        (fun () ->
           let term = freshen "{L, hyp A |- hyp B}" in
             match case term with
               | [{new_vars=[d] ; new_hyps=[hyp1; hyp2]}] ->
                   assert_pprint_equal "member D (hyp A :: L)" hyp1 ;
                   assert_pprint_equal "{L, hyp A >> D |- hyp B}" hyp2
               | _ -> assert_failure "Pattern mismatch") ;

      "Backchain case should get restriction from object" >::
        (fun () ->
           let term = freshen "{L |- p1 A}@" in
             match case term with
               | [{new_vars=[d] ; new_hyps=[hyp1; hyp2]}] ->
                   assert_pprint_equal "member D L" hyp1 ;
                   assert_pprint_equal "{L >> D |- p1 A}*" hyp2
               | _ -> assert_failure "Pattern mismatch") ;

      "Should pass along context" >::
        (fun () ->
           let term = freshen "{L |- p1 A}" in
           let clauses = parse_clauses "p1 X :- p2 X." in
             match case ~clauses term with
               | [case1; case2] ->
                   (* case1 is the member case *)

                   set_bind_state case2.bind_state ;
                   begin match case2.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "{L |- p2 A}" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end ;
               | cases -> assert_expected_cases 3 cases) ;

      "On atomic backchain" >::
        (fun () ->
           let term = freshen "{L >> p1 A |- p1 B}" in
             match case term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [] ->
                         assert_pprint_equal "{L >> p1 B |- p1 B}" term ;
                     | _ -> assert_failure "Expected no new hypotheses"
                   end ;
               | cases -> assert_expected_cases 1 cases) ;

      "On simple backchain" >::
        (fun () ->
           let term = freshen "{L >> pi x\\ p1 x => p2 x |- p2 A}" in
             match case term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "{L |- p1 A}" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end ;
               | cases -> assert_expected_cases 1 cases) ;

      "On invalid backchain" >::
        (fun () ->
           let term = freshen "{L >> pi x\\ p1 x => D |- p2 A}" in
             assert_raises
               (Failure "Cannot perform case-analysis on flexible clause")
               (fun () -> case term)) ;

      "On member" >::
        (fun () ->
           let term = freshen "member (hyp A) (hyp C :: L)" in
           let defs =
             parse_defs ("member A (A :: L) ;" ^
                           "member A (B :: L) := member A L.")
           in
             match case ~defs term with
               | [case1; case2] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "member (hyp C) (hyp C :: L)" term ;

                   set_bind_state case2.bind_state ;
                   begin match case2.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "member (hyp A) L" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 2 cases) ;

      "On exists should raise over support" >::
        (fun () ->
           let term = freshen "exists A, rel1 A n1" in
           let used = [] in
             match case ~used term with
               | [{new_hyps=[hyp]}] ->
                   assert_pprint_equal "rel1 (A n1) n1" hyp
               | _ -> assert_failure "Pattern mismatch") ;

      "Should raise over nominal variables in definitions" >::
        (fun () ->
           let defs = parse_defs "rel1 M N." in
           let term = freshen "rel1 (A (n1:i)) B" in
             match case ~defs term with
               | [case1] -> ()
               | cases -> assert_expected_cases 1 cases) ;

      "Should raise over nominal variables in clauses" >::
        (fun () ->
           let clauses = parse_clauses "eq M N." in
           let term = freshen "{eq (A (n1:i)) B}" in
             match case ~clauses term with
               | [case1] -> ()
               | cases -> assert_expected_cases 1 cases) ;

      "Should raise when nabla in predicate head" >::
        (fun () ->
           let defs =
             parse_defs "nabla x, ctx (hyp x :: L) := ctx L." in
           let term = freshen "ctx K" in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "ctx (hyp n1 :: L)" term
               | cases -> assert_expected_cases 1 cases) ;

      "Should permute when nabla is in the head" >::
        (fun () ->
           let defs =
             parse_defs "nabla x, ctx (hyp x :: L) := ctx L." in
           let term = freshen "ctx (K (n2:i))" in
           let global_support = [nominal_var "n2" ity] in
             match case ~defs ~global_support term with
               | [case1; case2] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "ctx (hyp n1 :: L n2)" term ;

                   set_bind_state case2.bind_state ;
                   assert_pprint_equal "ctx (hyp n2 :: L)" term
               | cases -> assert_expected_cases 2 cases) ;

      "With multiple nabla in the head" >::
        (fun () ->
           let defs =
             parse_defs "nabla x y, ctx (eq x y :: L) := ctx L." in
           let term = freshen "ctx (K (n2:i))" in
           let global_support = [nominal_var "n2" ity] in
             match case ~defs ~global_support term with
               | [case1; case2; case3] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "ctx (eq n1 n3 :: L n2)" term ;

                   set_bind_state case2.bind_state ;
                   assert_pprint_equal "ctx (eq n1 n2 :: L)" term ;

                   set_bind_state case3.bind_state ;
                   assert_pprint_equal "ctx (eq n2 n1 :: L)" term ;
               | cases -> assert_expected_cases 3 cases) ;

      "Should not use existing nabla variables as fresh" >::
        (fun () ->
           let defs = parse_defs "nabla x, foo x." in
           let term = freshen "foo A" in
           let global_support = [nominal_var "n1" ity] in
             match case ~defs ~global_support term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "foo n2" term
               | cases -> assert_expected_cases 1 cases) ;

      "Should not apply to coinductive restriction" >::
        (fun () ->
           let term = freshen "foo A +" in
             assert_raises
               (Failure "Cannot case analyze hypothesis\
                         \ with coinductive restriction")
               (fun () -> case term)) ;

      "Non-llambda equality should result in equalities" >::
        (fun () ->
           let term = freshen "foo (r1 t1) = foo (A (B:i))" in
             match case term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "r1 t1 = A B" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Non-llambda definition should result in equalities" >::
        (fun () ->
           let term = freshen "foo (A (B:i))" in
           let defs = parse_defs "foo (r1 t1)."
           in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "foo (A B)" term ;

                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "r1 t1 = A B" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Non-llambda clause should result in equalities" >::
        (fun () ->
           let term = freshen "{p1 (A (B:i))}" in
           let clauses = parse_clauses "p1 (r1 t1)."
           in
             match case ~clauses term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "{p1 (A B)}" term ;

                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "r1 t1 = A B" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Should not work on flexible clause head" >::
        (fun () ->
           let term = freshen "{P}" in
           let clauses = parse_clauses "p1 t1."
           in
             assert_raises
               (Failure "Cannot perform case-analysis on flexible head")
               (fun () -> case ~clauses term)) ;

    ]

let induction_tests =
  "Induction" >:::
    [
      "Single" >::
        (fun () ->
           let stmt = freshen
               "forall A, {hyp A} -> {conc A} -> {form A}" in
           let (ih, goal) = single_induction 1 1 stmt in
             assert_pprint_equal
               "forall A, {hyp A}* -> {conc A} -> {form A}"
               ih ;
             assert_pprint_equal
               "forall A, {hyp A}@ -> {conc A} -> {form A}"
               goal) ;

      "Nested" >::
        (fun () ->
           let stmt = freshen
               "forall A, {hyp A} -> {conc A} -> {form A}" in
           let (ih, goal) = single_induction 1 1 stmt in
             assert_pprint_equal
               "forall A, {hyp A}* -> {conc A} -> {form A}" ih ;
             assert_pprint_equal
               "forall A, {hyp A}@ -> {conc A} -> {form A}" goal ;
             let (ih, goal) = single_induction 2 2 goal in
               assert_pprint_equal
                 "forall A, {hyp A}@ -> {conc A}** -> {form A}" ih ;
               assert_pprint_equal
                 "forall A, {hyp A}@ -> {conc A}@@ -> {form A}" goal) ;

      "With OR on left of arrow" >::
        (fun () ->
           let stmt = freshen "forall (X:i), {A} \\/ {B} -> {C} -> {D}" in
           let (ih, goal) = single_induction 2 1 stmt in
             assert_pprint_equal
               "forall X, {A} \\/ {B} -> {C}* -> {D}"
               ih ;
             assert_pprint_equal
               "forall X, {A} \\/ {B} -> {C}@ -> {D}"
               goal) ;

      "On predicate" >::
        (fun () ->
           let stmt = freshen
             "forall A, foo A -> bar A -> baz A" in
           let (ih, goal) = single_induction 1 1 stmt in
             assert_pprint_equal
               "forall A, foo A * -> bar A -> baz A"
               ih ;
             assert_pprint_equal
               "forall A, foo A @ -> bar A -> baz A"
               goal) ;

      "Mutual on objects" >::
        (fun () ->
           let stmt = freshen
             "(forall A, {hyp A} -> {conc A} -> {form A}) /\\
              (forall B, {form B} -> {conc B})" in
             match induction [2; 1] 1 stmt with
               | [ih1; ih2], goal ->
                  assert_pprint_equal
                    "forall A, {hyp A} -> {conc A}* -> {form A}"
                    ih1 ;
                   assert_pprint_equal
                     "forall B, {form B}* -> {conc B}"
                     ih2 ;
                   assert_pprint_equal
                     ("(forall A, {hyp A} -> {conc A}@ -> {form A}) /\\ " ^
                        "(forall B, {form B}@ -> {conc B})")
                     goal
               | _ -> failwith "Expected 2 inductive hypotheses") ;

    ]

let coinduction_tests =
  "CoInduction" >:::
    [
      "Single" >::
        (fun () ->
           let stmt = freshen "forall A, foo A -> bar A -> baz A" in
           let (ch, goal) = coinduction 1 stmt in
             assert_pprint_equal
               "forall A, foo A -> bar A -> baz A +"
               ch ;
             assert_pprint_equal
               "forall A, foo A -> bar A -> baz A #"
               goal) ;

      "Should fail on inductively restricted" >::
        (fun () ->
           let stmt = freshen "foo A *" in
             assert_raises
               (Failure "Cannot coinduct on inductively restricted goal")
               (fun () -> coinduction 1 stmt)) ;
    ]

let assert_search ?(clauses="") ?(defs="")
    ?(hyps=[]) ~goal ~expect () =
  let depth = 5 in
  let clauses = parse_clauses clauses in
  let defs = if defs = "" then [] else parse_defs defs in
  let mutual = List.map (fun (head, _) -> def_head_name head) defs in
  let alldefs = [(mutual, defs)] in
  let hyps = List.map (fun h -> ("", h)) (List.map freshen hyps) in
  let goal = freshen goal in
  let actual = Option.is_some (search ~depth ~hyps ~clauses ~alldefs goal) in
    if expect then
      assert_bool "Search should succeed" actual
    else
      assert_bool "Search should fail" (not actual)

let search_tests =
  "Search" >:::
    [
      "Should check hypotheses" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B}"]
             ~goal:"{eval A B}"
             ~expect: true
        );

      "Should should succeed if clause matches" >::
        (fun () ->
           assert_search ()
             ~clauses:eval_clauses_string
             ~goal:"{eval (abs R) (abs R)}"
             ~expect: true
        );

      "Should backchain on clauses" >::
        (fun () ->
           assert_search ()
             ~clauses:"p1 X :- p2 X, p3 X."
             ~hyps:["{p2 A}"; "{p3 A}"]
             ~goal:"{p1 A}"
             ~expect: true
        );

      "On matching atomic backchain" >::
        (fun () ->
           assert_search ()
             ~goal:"{L >> p1 A |- p1 A}"
             ~expect: true) ;

      "On non-matching atomic backchain" >::
        (fun () ->
           assert_search ()
             ~goal:"{L >> p1 A |- p1 B}"
             ~expect: false) ;

      "On matching simple backchain" >::
        (fun () ->
           assert_search ()
             ~hyps:["{L |- p1 A}"]
             ~goal:"{L >> pi x\\ p1 x => p2 x |- p2 A}"
             ~expect: true) ;

      "On non-matching simple backchain" >::
        (fun () ->
           assert_search ()
             ~hyps:["{L |- p1 A}"]
             ~goal:"{L >> pi x\\ p1 x => p1 x |- p2 A}"
             ~expect: false) ;

      "On matching direct seq" >::
        (fun () ->
           assert_search ()
             ~defs:"member A (A :: L); member A (B :: L) := member A L."
             ~goal:"{p1 A |- p1 A}"
             ~expect: true) ;

      "On non-matching direct seq" >::
        (fun () ->
           assert_search ()
             ~defs:"member A (A :: L); member A (B :: L) := member A L."
             ~goal:"{p2 A |- p1 A}"
             ~expect: false) ;

      "On matching advanced seq" >::
        (fun () ->
           assert_search ()
             ~defs:"member A (A :: L); member A (B :: L) := member A L."
             ~goal:"{p1 A, pi x\\ p1 x => p2 x |- p2 A}"
             ~expect: true) ;

      "On non-matching advanced seq" >::
        (fun () ->
           assert_search ()
             ~defs:"member A (A :: L); member A (B :: L) := member A L."
             ~goal:"{p1 A, pi x\\ p2 x => p2 x |- p2 A}"
             ~expect: false) ;

      "On left of OR" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B}"]
             ~goal:"{eval A B} \\/ false"
             ~expect: true
        );

      "On right of OR" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B}"]
             ~goal:"false \\/ {eval A B}"
             ~expect: true
        );

      "On AND" >::
        (fun () ->
           assert_search ()
             ~hyps:["{a}"; "{b}"]
             ~goal:"{a} /\\ {b}"
             ~expect: true
        );

      "On AND (failure)" >::
        (fun () ->
           assert_search ()
             ~hyps:["{a}"]
             ~goal:"{a} /\\ {b}"
             ~expect: false
        );

      "On exists" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists R, {eq (iapp M N) R}"
             ~expect: true
        );

      "On exists (double)" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists R1 R2, {eq (iapp M N) (iapp R1 R2)}"
             ~expect: true
        );

      "On exists (failure)" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists R, {eq (iapp M N) (iapp R R)}"
             ~expect: false
        );

      "On forall" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"forall X, {eq X X}"
             ~expect:true
        );

      "On forall (2)" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"forall X, exists Y, {eq X Y}"
             ~expect:true
        );

      "On forall (failure)" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists Y, forall X, {eq X Y}"
             ~expect:false
        );

      "On arrow" >::
        (fun () ->
           assert_search ()
             ~goal:"{a} -> {a}"
             ~expect:true
        );

      "On arrow (failure)" >::
        (fun () ->
           assert_search ()
             ~goal:"{a} -> {b}"
             ~expect:false
        );

      "On forall, arrow, unfold" >::
        (fun () ->
           assert_search ()
             ~defs:"foo X := bar X"
             ~goal:"forall Z, bar Z -> foo Z"
             ~expect:true
        );

      "Should unbind on backtracking over equality" >::
        (fun () ->
           assert_search ()
             ~hyps:["{p2 t2}"]
             ~goal:"exists X, (X = t1 \\/ X = t2) /\\ {p2 X}"
             ~expect:true
        );

      "Should use meta unification" >::
        (fun () ->
           assert_search ()
             ~hyps:["{a} /\\ {b}"]
             ~goal:"{a} /\\ {b}"
             ~expect: true
        );

      "Should fail if there is no proof" >::
        (fun () ->
           assert_search ()
             ~clauses:eval_clauses_string
             ~goal:"{eval A B}"
             ~expect: false
        );

      "Should fail if hypothesis has non-subcontext" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B |- eval A B}"]
             ~goal:"{eval A B}"
             ~expect: false
        );

      "Should preserve context while backchaining" >::
        (fun () ->
           assert_search ()
             ~clauses:eval_clauses_string
             ~defs:"member A (A :: L); member A (B :: L) := member A L."
             ~goal:"{eval M (abs R), eval (R N) V |- eval (app M N) V}"
             ~expect: true
        );

      "Should move implies to the left" >::
        (fun () ->
           assert_search ()
             ~hyps:["{a |- b}"]
             ~goal:"{a => b}"
             ~expect: true
        );

      "Should replace pi x\\ with nominal variable" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eq n1 n1}"]
             ~goal:"{pi x\\ eq x x}"
             ~expect: true
        );

      "Should look for member" >::
        (fun () ->
           assert_search ()
             ~hyps:["member (hyp A) L"]
             ~goal:"{L |- hyp A}"
             ~expect: true
        );

      "On nablas" >::
        (fun () ->
           assert_search ()
             ~hyps:["rel1 n1 n2"]
             ~goal:"nabla x y, rel1 x y"
             ~expect: true
        );

      "Should backchain on definitions" >::
        (fun () ->
           assert_search ()
             ~defs:"member A (B :: L) := member A L."
             ~hyps:["member E K"]
             ~goal:"member E (F :: K)"
             ~expect: true
        );

      "Should undo partial results in favor of overall goal" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A"; "foo B"; "bar B"]
             ~goal:"exists X, foo X /\\ bar X"
             ~expect:true
        );

      "Should raise definitions over support" >::
        (fun () ->
           assert_search ()
             ~defs:"foo X."
             ~goal:"foo (A (n1:i))"
             ~expect: true
        );

      "Should raise object clauses over support" >::
        (fun () ->
           assert_search ()
             ~clauses:"p1 X."
             ~goal:"{p1 (A (n1:i))}"
             ~expect: true
        );

      "Should raise exists over support" >::
        (fun () ->
           assert_search ()
             ~hyps:["rel1 n1 n1"]
             ~goal:"exists X, rel1 n1 X"
             ~expect: true
        );

      "Should raise exists over global support" >::
        (fun () ->
           assert_search ()
             ~hyps:["rel1 n1 n1"]
             ~goal:"exists X, rel1 X X"
             ~expect: true
        );

      "Should work with nabla in the head" >::
        (fun () ->
           assert_search ()
             ~defs:"nabla x, ctx (hyp x :: L) := ctx L."
             ~hyps:["ctx L"]
             ~goal:"ctx (hyp n1 :: L)"
             ~expect: true
        );

      "Should work with nabla in the head despite nominal name" >::
        (fun () ->
           assert_search ()
             ~defs:"nabla x, ctx (hyp x :: L) := ctx L."
             ~hyps:["ctx L"]
             ~goal:"ctx (hyp n2 :: L)"
             ~expect: true
        );

      "Should work with multiple nabla in the head" >::
        (fun () ->
           assert_search ()
             ~defs:"nabla x y, ctx (eq x y :: L) := ctx L."
             ~hyps:["ctx L"]
             ~goal:"ctx (eq n3 n2 :: L)"
             ~expect: true
        );

      "Should permute nominal constants" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo n1"]
             ~goal:"foo n2"
             ~expect: true
        );

      "Should permute nominal constants in derivability" >::
        (fun () ->
           assert_search ()
             ~hyps:["{L, hyp n1 |- conc n2}"]
             ~goal:"{L, hyp n2, hyp n3 |- conc n2}"
             ~expect:true
        );

      "Should match derivable backchain" >::
        (fun () ->
           assert_search ()
             ~hyps:["{L, hyp n1 >> D |- conc n2}"]
             ~goal:"{L, hyp n2, hyp n3 >> D |- conc n2}"
             ~expect:true
        );

      "Should delay non-llambda pairs for clauses - simple" >::
        (fun () ->
           assert_search ()
             ~hyps:["{pr t1 (iabs r1)}"; "{pr t2 t3}"]
             ~goal:"{pr (iapp t1 t2) (r1 t3)}"
             ~clauses:"pr (iapp A B) (C D) :- pr A (iabs C), pr B D."
             ~expect:true
        );

      "Should delay non-llambda pairs for clauses - complex" >::
        (fun () ->
           assert_search ()
             ~hyps:["{pr t1 (iabs (iapp t2))}"; "{pr t3 (r2 t4)}"]
             ~goal:"{pr (iapp t1 t3) (iapp t2 (r2 t4))}"
             ~clauses:"pr (iapp A B) (C D) :- pr A (iabs C), pr B D."
             ~expect:true
        );

      "Should delay non-llambda pairs for defs - simple" >::
        (fun () ->
           assert_search ()
             ~hyps:["rel1 t1 (iabs r1)"; "rel1 t2 t3"]
             ~goal:"rel1 (iapp t1 t2) (r1 t3)"
             ~defs:"rel1 (iapp A B) (C D) := rel1 A (iabs C) /\\ rel1 B D."
             ~expect:true
        );

      "Should not match co-restricted hypothesis (1)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo t1 +"]
             ~goal:"foo t1"
             ~expect:false
        );

      "Should not match co-restricted hypothesis (2)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo t1 +"]
             ~goal:"foo t1 @"
             ~expect:false
        );

      "Should match co-restricted hypothesis after unfolding" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A +"]
             ~goal:"foo (r1 A) #"
             ~defs:"foo (r1 X) := foo X."
             ~expect:true
        );

      "Should match restricted hypothesis" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A *"]
             ~goal:"foo A *"
             ~expect:true
        );

      "Should match restricted hypothesis (2)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A @"]
             ~goal:"foo A @"
             ~expect:true
        );

      "Should match restricted hypothesis (3)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A *"]
             ~goal:"foo A @"
             ~expect:true
        );

      "Should not match different restricted hypothesis" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A **"]
             ~goal:"foo A *"
             ~expect:false
        );

      "Should not match different restricted hypothesis (2)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A @"]
             ~goal:"foo A *"
             ~expect:false
        );

      "Should not unfold definition in restricted goal" >::
        (fun () ->
           assert_search ()
             ~hyps:["bar A *"]
             ~goal:"foo A *"
             ~defs:"foo X := bar X."
             ~expect:false
        );

      "Should not unfold clause in restricted goal" >::
        (fun () ->
           assert_search ()
             ~hyps:["{hyp A}*"]
             ~goal:"{conc A}*"
             ~clauses:"conc X :- hyp X."
             ~expect:false
        );

    ]

let unfold ~defs goal =
  let mutual = List.map (fun (head, _) -> def_head_name head) defs in
  let mdefs = (mutual, defs) in
    unfold ~mdefs goal

let unfold_tests =
  "Unfold" >:::
    [
      "Should pick matching clause" >::
        (fun () ->
           let defs =
             parse_defs "foo (r1 X) := bar X; foo (r2 X) := baz X."
           in
           let goal = freshen "foo (r2 t1)" in
           let result = unfold ~defs goal in
             assert_pprint_equal "baz t1" result) ;

      "Should work with nominals" >::
        (fun () ->
           let defs = parse_defs "foo X := bar X." in
           let goal = freshen "foo (r1 n1)" in
           let result = unfold ~defs goal in
             assert_pprint_equal "bar (r1 n1)" result) ;

      "Should avoid variable capture" >::
        (fun () ->
           let defs = parse_defs "foo X := forall A, rel1 X A." in
           let goal = freshen "foo A" in
           let result = unfold ~defs goal in
             assert_pprint_equal "forall A1, rel1 A A1" result) ;

      "Should work on nabla in the head (permute)" >::
        (fun () ->
           let defs = parse_defs "nabla x, rel1 x Z := bar Z." in
           let goal = freshen "rel1 n1 D" in
           let result = unfold ~defs goal in
             assert_pprint_equal "bar D" result) ;

      "Should reduce coinductive restriction" >::
        (fun () ->
           let defs = parse_defs "foo X := foo X." in
           let goal = freshen "foo D #" in
           let result = unfold ~defs goal in
             assert_pprint_equal "foo D +" result) ;

      "Should not work on inductively restricted definition" >::
        (fun () ->
           let defs = parse_defs "foo X := bar X." in
           let goal = freshen "foo A @" in
             assert_raises
               (Failure "Cannot unfold inductively restricted predicate")
               (fun () -> unfold ~defs goal)) ;
    ]

let permute_tests =
  "Permute" >:::
    [

      "Basic" >::
        (fun () ->
           let h = freshen "foo n1 -> bar n2" in
           let perm = [nominal_var "n1" ity; nominal_var "n2" ity] in
             assert_pprint_equal
               "foo n2 -> bar n1"
               (permute_nominals perm h)) ;

      "Should avoid capture" >::
        (fun () ->
           let h = freshen "nabla n1, foo n1 -> bar n3" in
           let perm = [nominal_var "n1" ity; nominal_var "n3" ity] in
             assert_pprint_equal
               "nabla n2, foo n2 -> bar n1"
               (permute_nominals perm h)) ;

    ]

let assert_search_cut ~cut ~provable ~expect =
  let search_goal g = match g with
    | Obj(Seq(_, t), _) -> List.mem (term_to_string t) provable
    | _ -> false
  in
  match freshen cut with
    | Obj(Seq(ctx, t), _) ->
        let actual = Obj(Seq(search_cut ~search_goal ctx, t), Irrelevant) in
          assert_pprint_equal expect actual
    | _ -> assert false

let search_cut_tests =
  "Search Cut" >:::
    [
      "Simple" >::
        (fun () ->
           assert_search_cut
             ~cut:      "{a, b, c |- d}"
             ~provable: ["a"; "c"]
             ~expect:   "{b |- d}"
        );
    ]

let tests =
  "Tactics" >:::
    [
      object_cut_tests ;
      object_instantiation_tests ;
      apply_tests ;
      backchain_tests ;
      case_tests ;
      induction_tests ;
      coinduction_tests ;
      search_tests ;
      unfold_tests ;
      permute_tests ;
      search_cut_tests ;
    ]
