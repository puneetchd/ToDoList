//
//  TasksViewController.swift
//  ToDoList
//
//  Created by Radu Ursache on 21/02/2019.
//  Copyright © 2019 Radu Ursache. All rights reserved.
//

import UIKit
import RealmSwift
import LKAlertController
import IceCream

enum SortType: String {
    case Date = "date"
    case Priority = "priority"
}

class TasksViewController: BaseViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addTaskButton: UIButton!
    
    let searchController = UISearchController(searchResultsController: nil)
    
    var selectedType: HomeItemModel.ListType = .All
    var tasksDataSource: Results<TaskModel>!
    var tasksFilteredDataSource: Results<TaskModel>!
    var customIntervalDate: ActionSheetDateTimeRangePicker.DateRange?
    var currentSortType: SortType = .Date
    var currentSortAscending = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setDefaultSorting()
        self.loadData()
    }

    @objc override func setupUI() {
        super.setupUI()
        
        self.addTaskButton.addTarget(self, action: #selector(self.addTaskButtonAction), for: .touchUpInside)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.itemWith(colorfulImage: UIImage(named: "sortIcon")!, target: self, action: #selector(self.sortButtonAction))
        
        Utils().themeView(view: self.addTaskButton)
        
        self.searchController.searchBar.tintColor = UIColor.white
        self.searchController.searchBar.barTintColor = Utils().getCurrentThemeColor()
        self.definesPresentationContext = true
        
        self.tableView.estimatedRowHeight = 60
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.tableHeaderView = self.searchController.searchBar
        
        
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))
    }
    
    override func setupBindings() {
        super.setupBindings()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.searchController.searchResultsUpdater = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.shouldReloadDataNotification), name: Config.Notifications.shouldReloadData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newCloudDataReceived), name: Notifications.cloudKitNewData.name, object: nil)
    }
    
    func loadData() {
        if selectedType == .All {
            self.tasksDataSource = RealmManager.sharedInstance.getTasks()
        } else if selectedType == .Today {
            self.tasksDataSource = RealmManager.sharedInstance.getTodayTasks()
        } else if selectedType == .Tomorrow {
            self.tasksDataSource = RealmManager.sharedInstance.getTomorrowTasks()
        } else if selectedType == .Week {
            self.tasksDataSource = RealmManager.sharedInstance.getWeekTasks()
        } else if selectedType == .Custom {
            guard let interval = self.customIntervalDate else {
                print("custom interval date nil")
                
                return
            }
            
            self.tasksDataSource = RealmManager.sharedInstance.getCustomIntervalTasks(startDate: interval.start, endDate: interval.end)
        }
        
        self.sortDataSource()
    }
    
    @objc func shouldReloadDataNotification() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.loadData()
        }
    }

    @objc func newCloudDataReceived() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadData()
        }
    }
    
    @objc func addTaskButtonAction() {
        self.addTaskAction(editMode: false, task: nil)
    }
    
    func addTaskAction(editMode: Bool = false, task: TaskModel?) {
        let addTaskVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "editTaskVC") as! EditTaskViewController
        addTaskVC.editMode = editMode
        addTaskVC.parentType = self.selectedType
        if editMode {
            addTaskVC.tempTask = task!
        }
        addTaskVC.onCompletion = {
            self.loadData()
        }
        addTaskVC.mustShowAlert = { (alertText) in
            Alert(title: "Success", message: alertText).showOK()
        }
        
        let navigationController = UINavigationController(rootViewController: addTaskVC)
        navigationController.modalPresentationStyle = .custom
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    func sortDataSource() {
        self.tasksDataSource = self.tasksDataSource.sorted(byKeyPath: self.currentSortType.rawValue, ascending: self.currentSortAscending)
        
        self.tableView.reloadData()
    }
    
    @objc func sortButtonAction() {
        let sortSheet = ActionSheet(title: "Sort tasks".localized(), message: nil)
        
        for sortOption in Config.General.sortTitles {
            sortSheet.addAction(sortOption, style: .default) { (action) in
                let itemIndex = Config.General.sortTitles.index(of: sortOption)!
                
                if itemIndex == 0 || itemIndex == 1 {
                    self.currentSortType = .Date
                } else if itemIndex == 2 || itemIndex == 3 {
                    self.currentSortType = .Priority
                }
                
                self.currentSortAscending = itemIndex % 2 == 0
                
                self.sortDataSource()
            }
        }
        
        sortSheet.addAction("Cancel".localized(), style: .cancel)
        
        sortSheet.presentIn(self)
        sortSheet.show()
    }
    
    func commentsButtonAction(task: TaskModel, indexPath: IndexPath) {
        let commentsVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "commentsVC") as! CommentsViewController
        
        commentsVC.currentTask = task
        commentsVC.showKeyboardAtLoad = false
        commentsVC.onCompletion = {
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        self.present(UINavigationController(rootViewController: commentsVC), animated: true, completion: nil)
    }
    
    func remindersButtonAction(task: TaskModel, indexPath: IndexPath) {
        let remindersVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "remindersVC") as! RemindersViewController
        remindersVC.currentTask = task
        remindersVC.onCompletion = {
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        self.present(UINavigationController(rootViewController: remindersVC), animated: true, completion: nil)
    }
    
    func setDefaultSorting() {
        if selectedType == .All {
            self.currentSortType = .Priority
        } else if selectedType == .Today {
            self.currentSortType = .Date
        } else if selectedType == .Tomorrow {
            self.currentSortType = .Date
        } else if selectedType == .Week {
            self.currentSortType = .Date
        }
    }
    
    func showTaskOptions(task: TaskModel, indexPath: IndexPath) {
        let taskOptionsSheet = ActionSheet(title: "Task options".localized(), message: nil)
        
        if Config.Features.showCompleteButtonInTaskOptions {
            taskOptionsSheet.addAction("Complete".localized(), style: .default) { (action) in
                self.completeTask(task: task)
            }
        }
        
        taskOptionsSheet.addAction("Edit".localized(), style: .default) { (action) in
            self.addTaskAction(editMode: true, task: task)
        }
        
        taskOptionsSheet.addAction("Comments".localized(), style: .default) { (action) in
            self.commentsButtonAction(task: task, indexPath: indexPath)
        }
        
        taskOptionsSheet.addAction("Reminders".localized(), style: .default) { (action) in
            self.remindersButtonAction(task: task, indexPath: indexPath)
        }
        
        taskOptionsSheet.addAction("Cancel".localized(), style: .cancel)
        
        taskOptionsSheet.presentIn(self)
        taskOptionsSheet.show()
    }
    
    @objc func completeTaskSelector(sender: UIButton) {
        self.completeTask(task: self.tasksDataSource[sender.tag])
    }
    
    func completeTask(task: TaskModel) {
        RealmManager.sharedDelegate().completeTask(task: task)
        
        self.loadData()
        
        Utils().showSuccessToast(viewController: self, message: "Task completed!".localized())
    }
    
    func deleteTask(task: TaskModel) {
        RealmManager.sharedDelegate().deleteTask(task: task, soft: true)
        
        self.loadData()
    }
    
    func filterDataSource(keyword: String) {
        self.tasksFilteredDataSource = self.tasksDataSource.filter("content CONTAINS '\(keyword)'")
        self.tableView.reloadData()
    }
    
    func isSearching() -> Bool {
        return searchController.isActive && searchController.searchBar.text != ""
    }
}

extension TasksViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        self.filterDataSource(keyword: searchController.searchBar.text ?? "")
    }
}

extension TasksViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.isSearching() ? self.tasksFilteredDataSource.count : self.tasksDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.getIdentifier(), for: indexPath) as! TaskTableViewCell
        
        let currentTask = (self.isSearching() ? self.tasksFilteredDataSource : self.tasksDataSource)[indexPath.row]
        
        cell.taskNameLabel.text = currentTask.content
        
        cell.checkBoxButton.tag = indexPath.row
        cell.checkBoxButton.addTarget(self, action: #selector(self.completeTaskSelector), for: .touchUpInside)
        
        if let taskDate = currentTask.date {
            if Calendar.current.isDateInToday(taskDate) {
                cell.taskDateLabel.text = "Today".localized() + ", " + Config.General.timeFormatter().string(from: taskDate)
            } else if Calendar.current.isDateInTomorrow(taskDate) {
                cell.taskDateLabel.text = "Tomorrow".localized() + ", " + Config.General.timeFormatter().string(from: taskDate)
            } else {
                cell.taskDateLabel.text = Config.General.dateFormatter().string(from: taskDate)
            }
            
            cell.taskDateLabel.isHidden = false
        } else {
            cell.taskDateLabel.isHidden = true
        }
        
        if currentTask.priority != 10 && Config.Features.enablePriority {
            cell.priorityButton.setTitle(Config.General.priorityTitles[currentTask.priority - 1], for: .normal)
            cell.priorityButton.setTitleColor(Config.General.priorityColors[currentTask.priority - 1], for: .normal)
            cell.priorityButton.isHidden = false
        } else {
            cell.priorityButton.isHidden = true
        }
        
        if currentTask.availableComments().count > 0, Config.Features.enableComments {
            cell.commentsButton.setTitle("\(currentTask.availableComments().count)", for: .normal)
            cell.commentsButton.isHidden = false
        } else {
            cell.commentsButton.isHidden = true
        }
        
        if currentTask.availableNotifications().count > 0 {
            cell.remindersButton.setTitle("\(currentTask.availableNotifications().count)", for: .normal)
            cell.remindersButton.isHidden = false
        } else {
            cell.remindersButton.isHidden = true
        }
        
        cell.layoutIfNeeded()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.showTaskOptions(task: (self.isSearching() ? self.tasksFilteredDataSource : self.tasksDataSource)[indexPath.row], indexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete".localized()) { (_, indexPath) in
            self.deleteTask(task: (self.isSearching() ? self.tasksFilteredDataSource : self.tasksDataSource)[indexPath.row])
        }
        return [deleteAction]
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let emptyView = UIView() ; emptyView.backgroundColor = .clear ; return emptyView
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return self.addTaskButton.frame.size.height + 30
    }
}
