/*C
* Introduction

Rewriting the Pyton language grammar to Bison grammar and generalisations.
This text is about rewriting a grammar to a simple one without the repeating constructs * and + and without construct ? for optional
C*/
/*C

The documentation.md file is generated by

(README.org in .gitignore)

Markdown export commands 
#+BEGIN_SRC emacs-lisp

(defun generate-readme-md ()
 (interactive)
 (setq buf02 (current-buffer))
 (setq file01 (concat (file-name-directory (buffer-file-name)) "/README.org") )
 (find-file file01)

 (setq buf01 (current-buffer))
 (switch-to-buffer buf02)
 (copy-to-buffer buf01 1 (point-max))
 (switch-to-buffer buf01)

 (goto-line 1)
 (replace-regexp "^[/][*]C$" "")
 (goto-line 1)
 (replace-regexp "^C[*][/]$" "")
 (save-buffer)
 (org-md-export-to-markdown)
 (kill-buffer)
 (switch-to-buffer buf02)
)
#+END_SRC

C*/
/*C
* Define operators

Have a look at the following documents about defining operators
http://www.swi-prolog.org/pldoc/doc_for?object=module/2
http://www.swi-prolog.org/pldoc/man?predicate=op/3
http://www.swi-prolog.org/pldoc/man?section=operators

C*/

/*C
In the hope to improve readability the following operators are defined
C*/

/*C
 The following manner give problems, why?
#+BEGIN_SRC emacs-lisp
 :-  op(    40,  fx,  [  'grammar', 'rule', 'a', 'n', 't'  ]), op(    50,  xf,  [  '+','*','?'  ]).
#+END_SRC

 The following forms are okay:

THE FIRST ONE IS NOT RECOGNISED, ONLY THE FIRST ONE!! NEED NEW VERSION SWI PROLOG?

#+BEGIN_SRC emacs-lisp
C*/

:- op(40, fx, gram1 ).
:- op(40, fx, gram ).
:- op(40, fx, rule ).
:- op(30, xfx, :: ).
:- op(40, fx, alt ).
:- op(40, fx, nont ).
:- op(40, fx, tok ).
:- op(40, fx, act ).
:- op(50, xf, '+').
:- op(50, xf, '*').
:- op(50, xf, ? ).

/*C
#+END_SRC

* Processing the grammar

#+BEGIN_EXAMPLE
New rules will be created during the process of rewriting.
Created rules will have sequence numbers which will also be easy to guess for the enduser.

new rules derived from 'old_rule' will be named old_rule_123__1seq (for +) or old_rule_123__0seq (for *)
(Thus it is needed to prevent input rule names ending in __0seq or __1seq, so that they do not colide with the new created rules.)
#+END_EXAMPLE

https://stackoverflow.com/questions/11364634/count-the-number-of-calls-of-a-clause

#+BEGIN_SRC emacs-lisp
C*/


nb_inc(Key):-
  nb_getval(Key, Old),
  succ(Old, New),
  nb_setval(Key, New).

% grammar is a list of rules

get_grammar(1,G) :-
G=gram [

/* rule is a list of alternatives */

rule root :: [ 
               /* alternative is a list of terminal and nonterminal symbols and semantic actions, where * means none or more, + means one or more, and ? means none or one */
               alt [ nont next, [tok tok_one,  tok tok_comma]*,  [tok tok_two, tok tok_comma]+ , [tok tok_three, tok tok_comma]? ,[tok tok_four]+, tok tok_seven, act '{$1=\'123\';}' ],
	       alt [ [ tok tok_eight, tok tok_comma]*, tok tok_eight]
	     ],
rule next :: [ alt [ [tok tok_five] * , [tok tok_six] ?] ]
].

/* alternativeIsSimple when there are no *,+,? in it */
/*
Uses 'contains_term' from:
http://www.swi-prolog.org/pldoc/doc/_SWI_/library/occurs.pl
*/
alternativeIsSimple(alt A) :- \+ contains_term( _ +, A), \+ contains_term( _ *, A), \+ contains_term( _ ?, A).

/* given a grammar, the rules are processed to get a resulting grammar that containes only rules with simple alternatives. */

simplifyGrammar(gram [], gram []).

simplifyGrammar(gram [rule N :: R| RestG], gram SimpleG) :- 
	nb_setval(seq0,1),nb_setval(seq1,1)
	,simplifyRule(rule N :: R, rule _ :: SimpleR, AdditionalRules)
	%,maplist(print,[R,SimpleR,AdditionalRules])
	,append(AdditionalRules, RestG, AllRestRules)
        ,simplifyGrammar(gram AllRestRules,gram SimpleAllRestG)
        ,append( [ rule N :: SimpleR], SimpleAllRestG, SimpleG).

/* given a rule its alternatives are simplified. The rule can get additional alternatives, but also new additional rules can be created */
/* call like
  simplifyRule( rule N :: R, rule N :: S, More)
  The input 'rule N :: R' gives the simple output 'rule N :: S' and a list of additional rules More.
  The More rules are not simplified yet and need to be simplified later.
*/
simplifyRule( rule N :: [], rule N :: [], []) :- !.  % ! is not really needed here because [] can not match elsewhere

simplifyRule( rule N :: [alt A | RestR], rule N :: SimpleR, AdditionalRules ) :- 
	alternativeIsSimple(alt A)
        , !
        ,simplifyRule( rule N :: RestR, rule N :: SimplifiedRestR, AdditionalRules), append( [alt A], SimplifiedRestR, SimpleR)
        .

simplifyRule( rule N :: [alt A | RestR], rule _ :: [alt SimplifiedAlternative |SimpleR], AdditionalRules ) :- 
        \+ alternativeIsSimple(alt A)
        , !
        , simplifyAlternative([],alt A, N,SimplifiedAlternative, AdditionalAlternatives,AdditionalRules1)
        , append(AdditionalAlternatives, RestR, CompleteRestR)
        , simplifyRule( rule N :: CompleteRestR, rule _ :: SimpleR, AdditionalRules2)
        , append(AdditionalRules1, AdditionalRules2, AdditionalRules)
        .

/* given an alternative any occurance of ? is simplified by replacing the alternative by two new alternatives of the same rule. The original alternative is removed.
Any occurance of * is simplified by replacing the alternative by two new alternatives of the same rule and adding two new rules. The original alternative is removed.
Any occurance of + is simplified by replacing the alternative by a new alternative of the same rule and adding two new rules. The original alternative is removed.
The rules added in * and + cases are of the same structure to each other, i.e. the same trick works the for both.

call like
simplifyAlternative(ProcessedPart,alt A, N,SimplifiedAlternative, AdditionalAlternatives, AdditionalRules)
gets the already processed part ProcessedPart of the alternative as input, the rest to be processed part A as input and the current rule name N as input and calculates a list SimplifiedAlternative and a list AdditionalAlternatives and a list AdditionalRules
*/

simplifyAlternative(_,alt [],_ ,[] , [], []) :- !.  % ! is not really needed here because [] can not match elsewhere

simplifyAlternative(ProcessedPart,alt [ [B|T]? | RestA],N , SimplifiedAlternative, [alt NewAlternative|AdditionalAlternatives], AdditionalRules) :- 
	!
        ,append([B|T],RestA,A1)
        ,simplifyAlternative(ProcessedPart, alt A1,N , SimplifiedAlternative, AdditionalAlternatives, AdditionalRules)
        ,append(ProcessedPart,RestA,NewAlternative)
        .

simplifyAlternative(ProcessedPart, alt [ [B|T]+ | RestA],N , SimplifiedAlternative, AdditionalAlternatives, AdditionalRules) :- 	
        !
        %,maplist(writeln,["step 1",ProcessedPart,[B|T],RestA])
        ,nb_getval(seq1,Seq1)
        ,atomics_to_string([N,Seq1,'_1seq'],'_',StringNewName)
        ,atom_string(NewName, StringNewName)
        ,nb_inc(seq1)
        ,simplifyAlternative(ProcessedPart, alt [ NewName | RestA],N , SimplifiedAlternative, AdditionalAlternatives, AdditionalRules1)
        ,append([NewName],[B|T],T1)
        ,append([rule NewName :: [ alt [B|T], alt T1 ]],AdditionalRules1,AdditionalRules)
        %,maplist(writeln,["step 2",SimplifiedAlternative,AdditionalRules])
        .

simplifyAlternative(ProcessedPart, alt [ [B|T]* | RestA],N , SimplifiedAlternative, AdditionalAlternatives, AdditionalRules) :-
        !
        %,maplist(writeln,["step 1",ProcessedPart,[B|T],RestA])
        ,nb_getval(seq0,Seq0)
        ,atomics_to_string([N,Seq0,'_0seq'],'_',StringNewName)
        ,atom_string(NewName, StringNewName)
        ,nb_inc(seq0)
        ,simplifyAlternative(ProcessedPart, alt [ NewName | RestA],N , SimplifiedAlternative, AdditionalAlternatives1, AdditionalRules1)
        ,append(ProcessedPart, RestA, OneMoreAlternative), append([alt OneMoreAlternative],AdditionalAlternatives1,AdditionalAlternatives)
        ,append([NewName],[B|T],T1)
        ,append([rule NewName :: [ alt [B|T], alt T1 ]],AdditionalRules1,AdditionalRules)
        %,maplist(writeln,["step 2",SimplifiedAlternative,AdditionalRules])
        .
	
simplifyAlternative(ProcessedPart,alt [ T | RestA],N , [T|SimplifiedAlternative], AdditionalAlternatives,AdditionalRules) :- 
	append(ProcessedPart,[T],NewProcessedPart)
        ,simplifyAlternative(NewProcessedPart,alt RestA, N, SimplifiedAlternative, AdditionalAlternatives, AdditionalRules).
/*C
#+END_SRC

#+BEGIN_SRC emacs-lisp
C*/
/*
NESTED * (AND NESTED *) WILL POSE A DIFFICULT PROBLEM (is this below correct? - yes it is except that next_1__0seq_1__0seq and next_1__0seq_2__0seq could be equal, but that does not matter?)
FORTUNATELY THERE A NO NESTINGS IN PYTHON GRAMMAR
https://docs.python.org/3/reference/grammar.html

simplifyGrammar( gram [ rule next :: [ alt [ [[tok tok_7]* ,tok tok_six]* ] ] ], S), print(S).

gram[
     rule next::[
		 alt[next_1__0seq],
		 alt[]],
    rule next_1__0seq::[
			alt[next_1__0seq_1__0seq,tok tok_six],
			alt[tok tok_six],
			alt[next_1__0seq_2__0seq,tok tok_six,next_1__0seq],
			alt[tok tok_six,next_1__0seq]],
    rule next_1__0seq_1__0seq::[
				alt[tok tok_7],
				alt[tok tok_7,next_1__0seq_1__0seq]],
    rule next_1__0seq_2__0seq::[
				alt[tok tok_7],
				alt[tok tok_7,next_1__0seq_2__0seq]]]

*/
/*C
#+END_SRC
C*/
