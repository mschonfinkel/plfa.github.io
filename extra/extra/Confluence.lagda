\begin{code}
module extra.Confluence where
\end{code}

## Imports

\begin{code}
open import extra.Substitution
open import extra.LambdaReduction
open import plfa.Denotational using (Rename)
open import plfa.Soundness using (Subst)
open import plfa.Untyped
   renaming (_—→_ to _——→_; _—↠_ to _——↠_; begin_ to commence_; _∎ to _fini)
import Relation.Binary.PropositionalEquality as Eq
open Eq using (_≡_; _≢_; refl; trans; sym; cong; cong₂; cong-app)
open Eq.≡-Reasoning using (begin_; _≡⟨⟩_; _≡⟨_⟩_; _∎)
open import Function using (_∘_)
open import Data.Product using (_×_; Σ; Σ-syntax; ∃; ∃-syntax; proj₁; proj₂)
     renaming (_,_ to ⟨_,_⟩)
\end{code}

## Introduction

In this chapter we prove that beta reduction is _confluent_.  That is,
if there is a reduction sequence from any term `M` to two different
terms `N` and `N'`, then there exist reduction sequences from those
two terms to some common term `L`.

Confluence is studied in many other kinds of rewrite systems besides
the lambda calculus, and it is well known how to prove confluence in
rewrite systems that enjoy the _diamond property_, a single-step
version of confluence. Let `⇒` be a relation.  Then `⇒` has the
diamond property if `M ⇒ N` and `M ⇒ N'`, then there exists an `L`
such that `N ⇒ L` and `N' ⇒ L`. Let `⇒*` stand for sequences of `⇒`
reductions. The proof of confluence requires one easy lemma, that if
`M ⇒ N` and `M ⇒* N'`, then there exists an `L` such that `N ⇒* L` and
`N' ⇒ L.  With this lemma in hand, confluence is proved by induction
on the reduction sequence `M ⇒* N`.

Unfortunately, reduction in the lambda calculus does not satisfy the
diamond property. Here is a counter example.

    (λ x. x x)((λ x. x) a) —→ (λ x. x x) a
    (λ x. x x)((λ x. x) a) —→ ((λ x. x) a) ((λ x. x) a)
    
Both terms can reduce to `a a`, but the second term requires two steps
to get there, not one.

To side-step this problem, we'll define an auxilliary reduction
relation, called _parallel reduction_, that can perform many
reductions simultaneously and thereby satisfy the diamond property.
Furthermore, we will show that a parallel reduction sequence exists
between any two terms if and only if a reduction sequence exists
between them.  Thus, confluence for reduction will fall out as a
corollary to confluence for parallel reduction.


## Parallel Reduction

The parallel reduction relation is defined as follows.

\begin{code}
infix 2 _⇒_

data _⇒_ : ∀ {Γ A} → (Γ ⊢ A) → (Γ ⊢ A) → Set where

  pvar : ∀{Γ A}{x : Γ ∋ A}
         ---------
       → (` x) ⇒ (` x)

  pabs : ∀{Γ}{N N' : Γ , ★ ⊢ ★}
       → N ⇒ N'
         ----------
       → ƛ N ⇒ ƛ N'

  papp : ∀{Γ}{L L' M M' : Γ ⊢ ★}
       → L ⇒ L'  →  M ⇒ M'
         -----------------
       → L · M ⇒ L' · M'

  pbeta : ∀{Γ}{N N'  : Γ , ★ ⊢ ★}{M M' : Γ ⊢ ★}
       → N ⇒ N'  →  M ⇒ M'
         -----------------------
       → (ƛ N) · M  ⇒  N' [ M' ]
\end{code}

We remark that the `pabs`, `papp`, and `pbeta` rules perform reduction
on all their subexpressions simultaneously. Also, the `pabs` rule is
akin to the `ζ` rule and `pbeta` is akin to `β`.

Parallel reduction is reflexive.

\begin{code}
par-refl : ∀{Γ A}{M : Γ ⊢ A} → M ⇒ M
par-refl {Γ} {A} {` x} = pvar
par-refl {Γ} {★} {ƛ N} = pabs par-refl
par-refl {Γ} {★} {L · M} = papp par-refl par-refl
\end{code}

We define the sequences of parallel reduction as follows.

\begin{code}
infix  2 _⇒*_
infix  1 init_
infixr 2 _⇒⟨_⟩_
infix  3 _□

data _⇒*_ : ∀ {Γ A} → (Γ ⊢ A) → (Γ ⊢ A) → Set where

  _□ : ∀ {Γ A} (M : Γ ⊢ A)
      --------
    → M ⇒* M

  _⇒⟨_⟩_ : ∀ {Γ A} (L : Γ ⊢ A) {M N : Γ ⊢ A}
    → L ⇒ M
    → M ⇒* N
      ---------
    → L ⇒* N

init_ : ∀ {Γ} {A} {M N : Γ ⊢ A}
  → M ⇒* N
    ------
  → M ⇒* N
init M⇒*N = M⇒*N
\end{code}

## Equivalence between parallel reduction and reduction

Here we prove that for any `M` and `N`, `M ⇒* N` if and only if `M —↠ N`. 
The only-if direction is particularly easy. We start by showing
that if `M —→ N`, then `M ⇒ N`. The proof is by induction on
the reduction `M —→ N`.

\begin{code}
beta-par : ∀{Γ A}{M N : Γ ⊢ A}
         → M —→ N
           ------
         → M ⇒ N
beta-par {Γ} {★} {L · M} (ξ₁ r) = papp (beta-par {M = L} r) par-refl
beta-par {Γ} {★} {L · M} (ξ₂ r) = papp par-refl (beta-par {M = M} r) 
beta-par {Γ} {★} {(ƛ N) · M} β = pbeta par-refl par-refl
beta-par {Γ} {★} {ƛ N} (ζ r) = pabs (beta-par r)
\end{code}

With this lemma in hand we complete the only-if direction,
that `M —↠ N` implies `M ⇒* N`. The proof is a straightforward
induction on the reduction sequence `M —↠ N`.

\begin{code}
betas-pars : ∀{Γ A} {M N : Γ ⊢ A}
           → M —↠ N
             ------
           → M ⇒* N
betas-pars {Γ} {A} {M₁} {.M₁} (M₁ []) = M₁ □
betas-pars {Γ} {A} {.L} {N} (L —→⟨ b ⟩ bs) =
   L ⇒⟨ beta-par b ⟩ betas-pars bs
\end{code}

Now for the other direction, that `M ⇒* N` implies `M —↠ N`.  The
proof of this direction is a bit different because it's not the case
that `M ⇒ N` implies `M —→ N`. After all, `M ⇒ N` performs many
reductions. So instead we shall prove that `M ⇒ N` implies `M —↠ N`.

\begin{code}
par-betas : ∀{Γ A}{M N : Γ ⊢ A}
         → M ⇒ N
           ------
         → M —↠ N
par-betas {Γ} {A} {.(` _)} (pvar{x = x}) = (` x) []
par-betas {Γ} {★} {ƛ N} (pabs p) = abs-cong (par-betas p)
par-betas {Γ} {★} {L · M} (papp p₁ p₂) =
   —↠-trans (appL-cong{M = M} (par-betas p₁)) (appR-cong (par-betas p₂))
par-betas {Γ} {★} {(ƛ N) · M} (pbeta{N' = N'}{M' = M'} p₁ p₂) =
  let ih₁ = par-betas p₁ in
  let ih₂ = par-betas p₂ in
  let a : (ƛ N) · M —↠ (ƛ N') · M
      a = appL-cong{M = M} (abs-cong ih₁) in
  let b : (ƛ N') · M —↠ (ƛ N') · M'
      b = appR-cong{L = ƛ N'} ih₂ in
  let c = (ƛ N') · M' —→⟨ β ⟩ N' [ M' ] [] in
  —↠-trans (—↠-trans a b) c
\end{code}

The proof is by induction on `M ⇒ N`.

* Suppose `x ⇒ x`. We immediately have `x —↠ x`.

* Suppose `ƛ N ⇒ ƛ N'` because `N ⇒ N'`. By the induction hypothesis
  we have `N —↠ N'`. We conclude that `ƛ N —↠ ƛ N'` because
  `—↠` is a congruence.

* Suppose `L · M ⇒ L' · M'` because `L ⇒ L'` and `M ⇒ M'`.
  By the induction hypothesis, we have `L —↠ L'` and `M —↠ M'`.
  So `L · M —↠ L' · M` and then `L' · M  —↠ L' · M'`
  because `—↠` is a congruence. We conclude using the transitity
  of `—↠`.
  
* Suppose `(ƛ N) · M  ⇒  N' [ M' ]` because `N ⇒ N'` and `M ⇒ M'`.
  By similar reasoning, we have
  `(ƛ N) · M —↠ (ƛ N') · M'`.
  Of course, `(ƛ N') · M' —→ N' [ M' ]`, so we can conclude
  using the transitivity of `—↠`.
  
With this lemma in handle, we complete the proof that `M ⇒* N` implies
`M —↠ N` with a simple induction on `M ⇒* N`.

\begin{code}
pars-betas : ∀{Γ A} {M N : Γ ⊢ A}
           → M ⇒* N
             ------
           → M —↠ N
pars-betas (M₁ □) = M₁ []
pars-betas (L ⇒⟨ p ⟩ ps) = —↠-trans (par-betas p) (pars-betas ps)
\end{code}


## Substitution lemma for parallel reduction

Our next goal is the prove the diamond property for parallel
reduction. But to do that, we need to prove that substitution
respects parallel reduction. That is, if
`N ⇒ N'` and `M ⇒ M'`, then `N [ M ] ⇒ N' [ M' ]`.
We cannot prove this directly by induction, so we
generalize it to: if `N ⇒ N'` and
the substitution `σ` pointwise parallel reduces to `τ`,
then `subst σ N ⇒ subst τ N'`. We define the notion
of pointwise parallel reduction as follows.

\begin{code}
par-subst : ∀{Γ Δ} → Subst Γ Δ → Subst Γ Δ → Set
par-subst {Γ}{Δ} σ₁ σ₂ = ∀{A}{x : Γ ∋ A} → σ₁ x ⇒ σ₂ x
\end{code}

Because substitution depends on the extension function `exts`, which
in turn relies on `rename`, we start with a version of the
substitution lemma specialized to renamings.

\begin{code}
par-rename : ∀{Γ Δ A} {ρ : Rename Γ Δ} {M M' : Γ ⊢ A}
  → M ⇒ M'
    ------------------------
  → rename ρ M ⇒ rename ρ M'
par-rename pvar = pvar
par-rename (pabs p) = pabs (par-rename p)
par-rename (papp p₁ p₂) = papp (par-rename p₁) (par-rename p₂)
par-rename {Γ}{Δ}{A}{ρ} (pbeta{Γ}{N}{N'}{M}{M'} p₁ p₂)
     with pbeta (par-rename{ρ = ext ρ} p₁) (par-rename{ρ = ρ} p₂)
... | G rewrite rename-subst-commute{Γ}{Δ}{N'}{M'}{ρ} = G
\end{code}

The proof is by induction on `M ⇒ M'`. The first four cases
are straightforward so we just consider the last one for `pbeta`.

* Suppose `(ƛ N) · M  ⇒  N' [ M' ]` because `N ⇒ N'` and `M ⇒ M'`.
  By the induction hypothesis, we have
  `rename (ext ρ) N ⇒ rename (ext ρ) N'` and
  `rename ρ M ⇒ rename ρ M'`.
  So by `pbeta` we have
  `(ƛ rename (ext ρ) N) · (rename ρ M) ⇒ (rename (ext ρ) N) [ rename ρ M ]`.
  However, to conclude we instead need parallel reduction to
  `rename ρ (N [ M ])`. But thankfully, renaming and substitution
  commute with one another, that is,

        (rename (ext ρ) N) [ rename ρ M ] ≡ rename ρ (N [ M ])


With this lemma in hand, it is straightforward to show that extending
substitutions preserves the pointwise parallel reduction relation.

\begin{code}
par-subst-exts : ∀{Γ Δ} {σ τ : Subst Γ Δ}
   → par-subst σ τ
   → par-subst (exts σ {B = ★}) (exts τ)
par-subst-exts s {x = Z} = pvar
par-subst-exts s {x = S x} = par-rename s
\end{code}

We are ready to prove the main lemma regarding substitution and
parallel reduction.

\begin{code}
subst-par : ∀{Γ Δ A} {σ τ : Subst Γ Δ} {M M' : Γ ⊢ A}
   → par-subst σ τ  →  M ⇒ M'
     --------------------------
   → subst σ M ⇒ subst τ M'
subst-par {Γ} {Δ} {A} {σ} {τ} {` x} s pvar = s
subst-par {Γ} {Δ} {★} {σ} {τ} {ƛ N} s (pabs p) =
   pabs (subst-par {σ = exts σ} {τ = exts τ}
            (λ {A}{x} → par-subst-exts s {A}{x}) p)
subst-par {Γ} {Δ} {★} {σ} {τ} {L · M} s (papp p₁ p₂) =
   papp (subst-par s p₁) (subst-par s p₂)
subst-par {Γ} {Δ} {★} {σ} {τ} {(ƛ N) · M} s (pbeta{N' = N'}{M' = M'} p₁ p₂)
    with pbeta (subst-par{σ = exts σ}{τ = exts τ}{M = N}
                        (λ {A}{x} → par-subst-exts s {A}{x}) p₁)
               (subst-par (λ {A}{x} → s{A}{x}) p₂)
... | G rewrite subst-commute{N = N'}{M = M'}{σ = τ} =
    G
\end{code}

We proceed by induction on `M ⇒ M'`.

* Suppose `x ⇒ x`. We conclude that `σ x ⇒ τ x` using
  the premise `par-subst σ τ`.

* Suppose `ƛ N ⇒ ƛ N'` because `N ⇒ N'`.
  To use the induction hypothesis, we need `par-subst (exts σ) (exts τ)`,
  which we obtain by `par-subst-exts`.
  So then we have `subst (exts σ) N ⇒ subst (exts τ) N'`
  and conclude by rule `pabs`.
  
* Suppose `L · M ⇒ L' · M'` because `L ⇒ L'` and `M ⇒ M'`.
  By the induction hypothesis we have
  `subst σ L ⇒ subst τ L'` and `subst σ M ⇒ subst τ M'`, so
  we conclude by rule `papp`.

* Suppose `(ƛ N) · M  ⇒  N' [ M' ]` because `N ⇒ N'` and `M ⇒ M'`.
  Again we obtain `par-subst (exts σ) (exts τ)` by `par-subst-exts`.
  So by the induction hypothesis, we have
  `subst (exts σ) N ⇒ subst (exts τ) N'` and
  `subst σ M ⇒ subst τ M'`. So by rule `pbeta`, we have parallel reduction
  to `subst (exts τ) N' [ subst τ M' ]`.
  Substitution commutes with itself in the following sense.
  For any σ, N, and M, we have
  
        (subst (exts σ) N) [ subst σ M ] ≡ subst σ (N [ M ])

  So we have parallel reduction to `subst τ (N' [ M' ])`.


Of course, if `M ⇒ M'`, then `subst-zero M` pointwise parallel reduces
to `subst-zero M'`.

\begin{code}
par-subst-zero : ∀{Γ}{A}{M M' : Γ ⊢ A}
       → M ⇒ M'
       → par-subst (subst-zero M) (subst-zero M')
par-subst-zero {M} {M'} p {A} {Z} = p
par-subst-zero {M} {M'} p {A} {S x} = pvar
\end{code}

We conclude this section with the desired corollary, that substitution
respects parallel reduction.

\begin{code}
sub-par : ∀{Γ A B} {N N' : Γ , A ⊢ B} {M M' : Γ ⊢ A}
   → N ⇒ N' →  M ⇒ M'
     --------------------------
   → N [ M ] ⇒ N' [ M' ]
sub-par pn pm = subst-par (par-subst-zero pm) pn
\end{code}


## Parallel reduction satisfies the diamond property

The heart of this proof is made of stone, or rather, of diamond!  We
show that parallel reduction satisfies the diamond property: that if
`M ⇒ N` and `M ⇒ N'`, then `N ⇒ L` and `N' ⇒ L` for some `L`.  The
proof is relatively easy; it is parallel reduction's raison d'etre.
  
\begin{code}
par-diamond : ∀{Γ A} {M N N' : Γ ⊢ A}
  → M ⇒ N  →  M ⇒ N'
  → Σ[ L ∈ Γ ⊢ A ] (N ⇒ L)  ×  (N' ⇒ L)
par-diamond (pvar{x = x}) pvar = ⟨ ` x , ⟨ pvar , pvar ⟩ ⟩
par-diamond (pabs p1) (pabs p2)
    with par-diamond p1 p2
... | ⟨ L' , ⟨ p3 , p4 ⟩ ⟩ =
      ⟨ ƛ L' , ⟨ pabs p3 , pabs p4 ⟩ ⟩
par-diamond{Γ}{A}{L · M}{N}{N'} (papp{Γ}{L}{L₁}{M}{M₁} p1 p3)
                                (papp{Γ}{L}{L₂}{M}{M₂} p2 p4)
    with par-diamond p1 p2
... | ⟨ L₃ , ⟨ p5 , p6 ⟩ ⟩ 
    with par-diamond p3 p4
... | ⟨ M₃ , ⟨ p7 , p8 ⟩ ⟩ =
      ⟨ (L₃ · M₃) , ⟨ (papp p5 p7) , (papp p6 p8) ⟩ ⟩
par-diamond (papp (pabs p1) p3) (pbeta p2 p4)
    with par-diamond p1 p2
... | ⟨ N₃ , ⟨ p5 , p6 ⟩ ⟩ 
    with par-diamond p3 p4
... | ⟨ M₃ , ⟨ p7 , p8 ⟩ ⟩ =
    ⟨ N₃ [ M₃ ] , ⟨ pbeta p5 p7 , sub-par p6 p8 ⟩ ⟩
par-diamond (pbeta p1 p3) (papp (pabs p2) p4)
    with par-diamond p1 p2
... | ⟨ N₃ , ⟨ p5 , p6 ⟩ ⟩ 
    with par-diamond p3 p4
... | ⟨ M₃ , ⟨ p7 , p8 ⟩ ⟩ =
    ⟨ (N₃ [ M₃ ]) , ⟨ sub-par p5  p7 , pbeta p6 p8 ⟩ ⟩
par-diamond {Γ}{A} (pbeta p1 p3) (pbeta p2 p4)
    with par-diamond p1 p2
... | ⟨ N₃ , ⟨ p5 , p6 ⟩ ⟩ 
    with par-diamond p3 p4
... | ⟨ M₃ , ⟨ p7 , p8 ⟩ ⟩ =
      ⟨ N₃ [ M₃ ] , ⟨ sub-par p5 p7 , sub-par p6 p8 ⟩ ⟩
\end{code}

The proof is by induction on both premises.

* Suppose `x ⇒ x` and `x ⇒ x`.
  We choose `L = x` and immediately have `x ⇒ x` and `x ⇒ x`.

* Suppose `ƛ N ⇒ ƛ N'` and `ƛ N ⇒ ƛ N''`.
  By the induction hypothesis, there exists `L'` such that
  `N' ⇒ L'` and `N'' ⇒ L'`. We choose `L = ƛ L'` and
  by `pabs` conclude that `ƛ N' ⇒ ƛ L'` and `ƛ N'' ⇒ ƛ L'.

* Suppose that `L · M ⇒ L₁ · M₁` and `L · M ⇒ L₂ · M₂`.
  By the induction hypothesis we have
  `L₁ ⇒ L₃` and `L₂ ⇒ L₃` for some `L₃`.
  Likewise, we have
  `M₁ ⇒ M₃` and `M₂ ⇒ M₃` for some `M₃`.
  We choose `L = L₃ · M₃` and conclude with two uses of `papp`.

* Suppose that `(ƛ N) · M ⇒ (ƛ N₁) · M₁` and `(ƛ N) · M ⇒ N₂ [ M₂ ]`
  By the induction hypothesis we have
  `N₁ ⇒ N₃` and `N₂ ⇒ N₃` for some `N₃`.
  Likewise, we have
  `M₁ ⇒ M₃` and `M₂ ⇒ M₃` for some `M₃`.
  We choose `L = N₃ [ M₃ ]`.
  We have `(ƛ N₁) · M₁ ⇒ N₃ [ M₃ ]` by rule `pbeta`
  and conclude that `N₂ [ M₂ ] ⇒ N₃ [ M₃ ]` because
  substitution respects parallel reduction.

* Suppose that `(ƛ N) · M ⇒ N₁ [ M₁ ]` and `(ƛ N) · M ⇒ (ƛ N₂) · M₂`.
  The proof of this case is the mirror image of the last one.

* Suppose that `(ƛ N) · M ⇒ N₁ [ M₁ ]` and `(ƛ N) · M ⇒ N₂ [ M₂ ]`.
  By the induction hypothesis we have
  `N₁ ⇒ N₃` and `N₂ ⇒ N₃` for some `N₃`.
  Likewise, we have
  `M₁ ⇒ M₃` and `M₂ ⇒ M₃` for some `M₃`.
  We choose `L = N₃ [ M₃ ]`.
  We have both `(ƛ N₁) · M₁ ⇒ N₃ [ M₃ ]`
  and `(ƛ N₂) · M₂ ⇒ N₃ [ M₃ ]`
  by rule `pbeta`
  

## Proof of confluence for parallel reduction

\begin{code}
par-confR : ∀{Γ A} {M N N' : Γ ⊢ A}
  → M ⇒ N  →  M ⇒* N'
  → Σ[ L ∈ Γ ⊢ A ] (N ⇒* L)  ×  (N' ⇒ L)
par-confR{Γ}{A}{M}{N}{N'} mn (M □) = ⟨ N , ⟨ N □ , mn ⟩ ⟩
par-confR{Γ}{A}{M}{N}{N'} mn (_⇒⟨_⟩_ M {M'} mm' mn')
    with par-diamond mn mm'
... | ⟨ L , ⟨ nl , m'l ⟩ ⟩
    with par-confR m'l mn'
... | ⟨ L' , ⟨ ll' , n'l' ⟩ ⟩ =
    ⟨ L' , ⟨ (N ⇒⟨ nl ⟩ ll') , n'l' ⟩ ⟩
\end{code}

\begin{code}
par-confluence : ∀{Γ A} {M N N' : Γ ⊢ A}
  → M ⇒* N  →  M ⇒* N'
  → Σ[ L ∈ Γ ⊢ A ] (N ⇒* L)  ×  (N' ⇒* L)
par-confluence {Γ}{A}{M}{N}{N'} (M □) m→n' = ⟨ N' , ⟨ m→n' , N' □ ⟩ ⟩
par-confluence {Γ}{A}{M}{N}{N'} (_⇒⟨_⟩_ M {M'} m→m' m'→n) m→n'
    with par-confR m→m' m→n'
... | ⟨ L , ⟨ m'→l , n'→l ⟩ ⟩
    with par-confluence m'→n m'→l
... | ⟨ L' , ⟨ n→l' , l→l' ⟩ ⟩ =
    ⟨ L' , ⟨ n→l' , (N' ⇒⟨ n'→l ⟩ l→l') ⟩ ⟩
\end{code}

## Proof of confluence for reduction

\begin{code}
confluence : ∀{Γ A} {M N N' : Γ ⊢ A}
  → M —↠ N  →  M —↠ N'
  → Σ[ L ∈ Γ ⊢ A ] (N —↠ L)  ×  (N' —↠ L)
confluence m→n m→n'
    with par-confluence (betas-pars m→n) (betas-pars m→n')
... |  ⟨ L , ⟨ n→l , n'→l ⟩ ⟩ =
    ⟨ L , ⟨ pars-betas n→l , pars-betas n'→l ⟩ ⟩
\end{code}


## Notes

UNDER CONSTRUCTION
