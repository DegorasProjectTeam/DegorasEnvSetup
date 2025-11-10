#include "view.h"
#include "ui_view.h"

View::View(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::View)
{
    ui->setupUi(this);

    QObject::connect(this->ui->pb_action, &QPushButton::clicked, this, &View::shortActionButtonClicked);

    QObject::connect(this->ui->pb_long_action, &QPushButton::clicked, this, &View::longActionButtonClicked);

    this->connect(this->ui->pb_long_action_view, &QPushButton::clicked, this, &View::longAction);

}

View::~View()
{
    delete ui;
}

void View::setVar1Text(const QString &text)
{
    this->ui->lb_var1->setText(text);
}

void View::setVar2Text(const QString &text)
{
    this->ui->lb_var2->setText(text);
}

void View::setStatusText(const QString &text)
{
    this->ui->lb_stat->setText(text);
}
