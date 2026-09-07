# Platform boundary checks

Run `flutter test test/architecture` alongside the runtime renderer matrix.

The source graph checks every owned `lib/src` file for mixed design imports and
exports. For each design it follows the canonical control/service registry,
every native design library, the app/scaffold/startup entrypoints, and an
explicit set of generic style-parser contracts. Local relative and `package:ruflet`
imports, exports, conditional alternatives, and registry/backend cycles are
traversed. An unused import is retained, not treated as evidence of safety.

An edge may be pruned only when all of its imported public symbol references
(including extension members, prefixes, type annotations and metadata) occur
inside the opposite design's AST-proven lazy branch. Recognized boundaries are
the canonical `PlatformControlRenderer` builder closures and exhaustive,
unguarded `PageDesign` switches on a typed design input or the canonical context
selector. The canonical dispatcher's constructor and build body are also
checked for side effects and exactly-one-builder evaluation. A file merely
containing a dispatcher is not a boundary for its shared or eager helpers.

Icon tables are an explicit data boundary, not a filename exemption. Their
entire library must consist of typed `List<IconData>` declarations initialized
only with static `Icons` or `CupertinoIcons` members. Functions, other
constructors, imports or declarations invalidate this classification. The
public barrel's Flutter design exports must expose only those icon-data classes.

The checker parses syntax; it is intentionally conservative rather than a full
Dart element resolver or execution proof. New dispatcher syntax is rejected
until supported and regression-tested. Package compilation remains necessary
to validate symbol/type resolution. Adversarial fixtures verify that eager
theme conversion, hidden exported helpers, registry cycles, type-only imports,
conditional dependencies and false icon exemptions cannot silently pass.

This check covers owned core source, not Flutter SDK internals or third-party
package bodies. External package URIs are recorded separately. In particular,
it does not claim that broad extension `ruflet.dart` imports imply runtime use of
every export, nor that a third-party dependency is safe because its package URI
does not name a design. Native widget/overlay interaction tests and the renderer
matrix complement this check; extension forks retain their own renderer tests.
