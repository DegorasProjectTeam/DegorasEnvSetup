#pragma once

#include <QMainWindow>
#include <thread>

QT_BEGIN_NAMESPACE
namespace Ui {
class View;
}
QT_END_NAMESPACE

class View : public QMainWindow
{
    Q_OBJECT

public:
    View(QWidget *parent = nullptr);
    ~View() override;

public slots:

    void setVar1Text(const QString &text);

    void setVar2Text(const QString &text);

    void setStatusText(const QString &text);

    void longAction()
    {

        std::this_thread::sleep_for(std::chrono::seconds(5));

    }

signals:

    void shortActionButtonClicked();

    void longActionButtonClicked();

private:

    Ui::View *ui;
};
