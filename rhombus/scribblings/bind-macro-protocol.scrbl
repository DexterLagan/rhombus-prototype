#lang scribble/rhombus/manual
@(import:
    "util.rhm" open
    "common.rhm" open)

@title[~tag: "bind-macro-protocol"]{Low-Level Binding Macros}

A binding form using the low-level protocol has three parts:

@itemlist[
  
 @item{A compile-time function to report ``upward'' @tech{static
   information} about the variables that it binds. The function receives
  ``downward'' information provided by the context, such as static
  information inferred for the right-hand side of a @rhombus[val] binding
  or imposed by enclosing binding forms. If a binding form has subforms,
  it can query those subforms, pushing its down information ``downward''
  and receiving the subform information ``upward''.},

 @item{A compile-time function that generates code that checks the
  input value for a match. The generated block may include additional
  definitions before branching or after branching toward success, but
  normally no bindings visible to code around the binding should be
  created at this step. Also, any action that commits to a binding match
  should be generated by the third compile-time function (in the next
  bullet).},

 @item{A compile-time function that generates definitions for the bound
  variables (i.e., the ones described by the function in the first bullet
  above). These definitions happen only after the match is successful, if
  at all, and the bindings are visible only after the matching part of the
  expansion. Also, these bindings are the ones that are affected by
  @rhombus[forward]. The generated definitions do not need to attach
  static information reported by the first bullet's function; that
  information will be attached by the definition form that drives the
  expansion of binding forms.}

]

The first of these functions, which produces static information, is
always called first, and its results might be useful to the second
two. Operationally, parsing a binding form gets the first function,
and then that function reports the other two along with the static
information that it computes.

To make binding work both in definition contexts and @rhombus[match]
search contexts, the check-generating function (second bullet above)
must be parameterized over the handling of branches. Toward that end, it
receives three extra arguments: the name of an @rhombus[if]-like form
that we'll call @rhombus[IF], a @rhombus[success] form, and a
@rhombus[failure] form. The transformer uses the given @rhombus[IF] to
branch to a block that includes @rhombus[success] or just
@rhombus[failure]. The @rhombus[IF] form must be used in tail position
with respect to the generated code, where the ``then'' part of an
@rhombus[IF] is still in tail position for nesting. The transformer must
use @rhombus[failure] and only @rhombus[failure] in the ``else'' part of
each @rhombus[IF], and it must use @rhombus[success] exactly once within
a ``then'' branch of one or more nested @rhombus[IF]s.

Unfortunately, there's one more complication. The result of a macro
must be represented as syntax—even a binding macro—and a functions as
a first-class compile-time value should not be used as syntax. (Such
representation are sometimes called ``3-D syntax,'' and they're best
avoided.) So, a low-level binding macro must uses a defunctionalized
representation of functions. That is, a parsed binding reports a
function name for its static-information compile-time function, plus
data to be passed to that function, and those two parts form a
closure. Among the static-information function's returns are names for
a match-generator and binding-generator function, plus data to be
passed to those functions (effectively: the fused closure for those
two functions).

In full detail, a low-level pared binding result from @rhombus[ bind.macro]
transformer is represented as a syntax object with two parts:

@itemlist[

 @item{The name of a compile-time function that is bound with
  @rhombus[bind.infoer].},
  
 @item{Data for the @rhombus[bind.infoer]-defined function, packaged as
  a single syntax object. This data might contain parsed versions of other
  binding forms, for example.}

]

These two pieces are assembled into a parenthesized-tuple syntax object,
and then packed with the @rhombus[bind_ct.pack] function to turn it into
a valid binding expansion (to distinguish the result from a macro
expansion in the sense of producing another binding form).

The function bound with @rhombus[bind.infoer] will receive two syntax
objects: a representation of ``downward'' static information and the
parsed binding's data. The result must be a single-object tuple with
seven parts:

@itemlist[

 @item{A string that is used for reporting a failed match. The string is
  used as an annotation, and it should omit information that is local to
  the binding. For example, when @rhombus[cons(x, y)] is used as a binding
  pattern, a suitable annotation string might be
  @rhombus["matching(cons(_, _))"] to phrase the binding constraint as an
  annotation and omit local variable names being bound (which should not
  be reported to the caller of a function, for example, when an argument
  value in a call of the function fails to match).},

 @item{An identifier that is used as a name for the input value, at least
   to the degree that the input value uses an inferred name. For
   example, @rhombus[proc] as a binding form should cause its rand-hand value
   to use the inferred name @rhombus[proc], if it can make any use of an
   inferred name.},

 @item{``Upward'' static information associated with the overall value for a
   successful match with the binding. This infomation is used by the
   @rhombus[matching] annotation operator, for example, as well as propagated
   outward by binding forms that correspond to composite data types.
   The information is independent of static information for individual
   names within the binding, but it should be the same as information
   for any binding that corresponds to the full matched value. For
   example, @rhombus[Posn(x, y)] binds @rhombus[x] and @rhombus[y], and it may not have any
   particular static information for @rhombus[x] and @rhombus[y], but a matching value
   has static information suitable for @rhombus[Posn], anyway; so, using
   @rhombus[p :: matching(Posn(_, _))] makes @rhombus[p] have @rhombus[Posn]
   static information.},

 @item{A list of invdidual names that are bound by the overall binding,
   plus ``upward'' [static information](static-info.md) for each name.
   For example, @rhombus[Posn(x, y)] as a binding pattern binds @rhombus[x] and @rhombus[y].
   The final transformer function described in the third bullet above
   is responsible for actually binding each name and associating
   static information with it. One piece of static information helps
   compose binding forms: the @rhombus[bind_ct.bind_input_key] key should be
   mapped to @rhombus[#true] for each name whose value corresponds to the
   binding input value, and the static information for such a name
   should otherwise match the static information reported in the
   second bullet above.},

 @item{The name of a compile-time function that is bound with
   @rhombus[bind.matcher].},

 @item{The name of a compile-time function that is bound with
   @rhombus[bind.binder]},

 @item{Data for the @rhombus[bind.matcher]- and
  @rhombus[bind.binder]-defined functions, packaged as a single syntax
  object.}
]

The functions bound with @rhombus[bind.matcher] and @rhombus[bind.binder] are called
with a syntax-object identifier for the matcher's input plus the data
from the sixth tuple slot. The match-building transformer in addition
receives the @rhombus[IF] form name, a @rhombus[success] form, and a @rhombus[failure] form.

Here's a use of the low-level protocol to implement a @rhombus[fruit] pattern,
which matches only things that are fruits according to @rhombus[is_fruit]:

@(rhombusblock:
    bind.macro '(fruit($id) $tail ......):
      values(bind_ct.pack('(fruit_infoer,
                            // remember the id:
                            $id)),
             tail)

    bind.infoer '(fruit_infoer($static_info, $id)):
      '("matching(fruit(_))",
        $id,
        // no overall static info:
        (),
        // `id` is bound:
        (($id, ())),
        fruit_matcher,
        fruit_binder,
        // binder needs id:
        $id)

    bind.matcher '(fruit_matcher($arg, $id, $IF, $success, $failure)):
      '(:
          $IF is_fruit($arg)
          | $success
          | $failure
      )

    bind.binder '(fruit_binder($arg, $id)):
      '(:
          def $id: $arg
      )

    fun is_fruit(v):
      v == "apple" || v == "banana"

    val fruit(snack): "apple"
    snack // prints "apple"

    // val fruit(dessert): "cookie"  // would fail with a match error
  )

The @rhombus[fruit] binding form assumes (without directly checking)
that its argument is an identifier, and its infoer discards static
information. Binding forms normally need to accomodate other, nested
binding forms, instead. A @rhombus[bind.macro] transformer with
@rhombus[parsed_right] receives already-parsed sub-bindings as
arguments, and the infoer function can use @rhombus[bind_ct.get_info] on
a parsed binding form to call its internal infoer function. The result
is packed static information, which can be unpacked into a tuple syntax
object with @rhombus[bin_ct.unpack_info]. Normally,
@rhombus[bind_ct.get_info] should be called only once to avoid
exponential work with nested bindings, but @rhombus[bind_ct.unpack_info]
can used any number of times.

As an example, here's an infix @rhombus[<&>] operator that takes two
bindings and makes sure a value can be matched to both. The binding
forms on either size of @rhombus[<&>] can bind variables. The
@rhombus[<&>] builder is responsible for binding the input name that
each sub-binding expects before it deploys the corresponding builder.
The only way to find out if a sub-binding matches is to call its
builder, providing the same @rhombus[IF] and @rhombus[failure] that the
original builder was given, and possibly extending the @rhombus[success]
form. A builder must be used in tail position, and it's
@rhombus[success] position is a tail position.

@(rhombusblock:
    bind.macro '($a <&> $b):
      ~parsed_right
      bind_ct.pack('(anding_infoer,
                     ($a, $b)))

    bind.infoer '(anding_infoer($in_id, ($a, $b))):
      val a_info: bind_ct.get_info(a, '())
      val b_info: bind_ct.get_info(b, '())
      val '($a_ann, $a_name, ($a_val_info ...), ($a_bind ...), $_, $_, $_): bind_ct.unpack_info(a_info)
      val '($b_ann, $b_name, ($b_val_info ...), ($b_bind ...), $_, $_, $_): bind_ct.unpack_info(b_info)
      val ann: "and(" & unwrap_syntax(a_ann) & ", " & unwrap_syntax(b_ann) & ")"
      '($ann,
        $a_name,
        ($a_val_info ... $b_val_info ...),
        ($a_bind ... $b_bind ...),
        anding_matcher,
        anding_binder,
        ($a_info, $b_info))

    bind.matcher '(anding_matcher($in_id, ($a_info, $b_info),
                                  $IF, $success, $failure)):
      val '($_, $_, $_, $_, $a_matcher, $_, $a_data): bind_ct.unpack_info(a_info)
      val '($_, $_, $_, $_, $b_matcher, $_, $b_data): bind_ct.unpack_info(b_info)
      '(:
          $a_matcher($in_id, $a_data, $IF,
                     $b_matcher($in_id, $b_data, $IF, $success, $failure),
                     $failure)
      )

    bind.binder '(anding_binder($in_id, ($a_info, $b_info))):
      val '($_, $_, $_, $_, $_, $a_binder, $a_data): bind_ct.unpack_info(a_info)
      val '($_, $_, $_, $_, $_, $b_binder, $b_data): bind_ct.unpack_info(b_info)
      '(:
          $a_binder($in_id, $a_data)
          $b_binder($in_id, $b_data)
      )

    val one <&> 1: 1
    one  // prints 1
    // value two <&> 1: 2 // would fail, since 2 does not match 1

    val Posn(0, y) <&> Posn(x, 1) : Posn(0, 1)
    x  // prints 0
    y  // prints 1
  )

One subtlety here is the syntactic category of @rhombus[IF] for a builder
call. The @rhombus[IF] form might be a definition form, or it might be
an expression form, and a builder is expected to work in either case, so
a builder call's category is the same as @rhombus[IF]. An @rhombus[IF]
alternative is written as a block, as is a @rhombus[success] form, but
the block may be inlined into a definition context.

The @rhombus[<&>] infoer is able to just combine any names and
``upward'' static information that receives from its argument bindings,
and it can simply propagate ``downward'' static information. When a
binding operator reflects a composite value with separate binding forms
for component values, then upward and downward information needs to be
adjusted accordingly.
