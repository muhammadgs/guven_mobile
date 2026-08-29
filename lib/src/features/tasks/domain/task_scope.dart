import 'task_item.dart';

/// The five cells of the bar above the task list.
///
/// Cell order is the design's, left to right. Each one is a different task
/// resource on the backend rather than a filter over one list, which is why
/// the controller keeps a separate cache per cell.
enum TaskScope {
  /// Öz şirkətimizin daxili tapşırıqları.
  internal(
    'Daxili',
    'assets/images/icons/task_list_selection_icons/daxili.svg',
    TaskSource.internal,
  ),

  /// Şirkətlərarası — tasks that came from, or went to, another company.
  company(
    'Şirkət',
    'assets/images/icons/task_list_selection_icons/sirket.svg',
    TaskSource.external,
  ),

  /// Partner tasks.
  partner(
    'Partniyor',
    'assets/images/icons/task_list_selection_icons/partniyor.svg',
    TaskSource.partner,
  ),

  /// Hesabat. Deliberately blank: it is being designed as something other
  /// than a list of task cards, so it fetches nothing and shows nothing until
  /// that design arrives.
  report(
    'Hesabat',
    'assets/images/icons/task_list_selection_icons/hesabat.svg',
    TaskSource.readOnly,
  ),

  /// Archived tasks.
  archive(
    'Arxiv',
    'assets/images/icons/task_list_selection_icons/arxiv.svg',
    TaskSource.readOnly,
  );

  const TaskScope(this.label, this.icon, this.source);

  final String label;
  final String icon;

  /// Which resource its rows belong to, and so which verbs act on them.
  final TaskSource source;

  /// Whether this cell has a task list behind it at all.
  ///
  /// Only [report] does not. Nothing is requested for it and nothing is drawn
  /// — an empty message would be a claim about data that was never asked for.
  bool get hasFeed => this != TaskScope.report;

  /// What an empty list says under this cell.
  String get emptyMessage => switch (this) {
    TaskScope.internal => 'Daxili tapşırıq yoxdur.',
    TaskScope.company => 'Şirkət tapşırığı yoxdur.',
    TaskScope.partner => 'Partniyor tapşırığı yoxdur.',
    TaskScope.report => '',
    TaskScope.archive => 'Arxivdə tapşırıq yoxdur.',
  };
}
